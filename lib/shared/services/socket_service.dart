import 'package:flutter/foundation.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class SocketService extends ChangeNotifier {
  AuthService _auth;
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _lastToken;

  SocketService(this._auth) {
    _lastToken = _auth.token;
    _initSocket();
  }

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (_lastToken != auth.token) {
      debugPrint("🔌 SocketService: Token changed, reinitializing socket...");
      _lastToken = auth.token;
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      _initSocket();
    }
  }

  void _initSocket() {
    final token = _auth.token;
    if (token == null) {
      if (_socket != null) {
        debugPrint("🔌 SocketService: Disconnecting socket because user is logged out.");
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
        _isConnected = false;
        notifyListeners();
      }
      return;
    }

    if (_socket != null) return;

    debugPrint("🔌 SocketService: Initializing socket connection...");
    // Deriving base url without '/api'
    final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .setAuth({'token': 'Bearer $token'})
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint("⚡ SocketService: Connected! ID: ${_socket!.id}");
      _isConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((reason) {
      debugPrint("🔌 SocketService: Disconnected. Reason: $reason");
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint("⚠️ SocketService: Connection error: $err");
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
