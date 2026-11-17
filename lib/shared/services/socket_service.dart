import 'dart:math';
import 'package:flutter/foundation.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/services/context_service.dart';
import 'package:flutter_application/shared/services/update_policy.dart';
import 'package:flutter_application/shared/widgets/update_gate.dart';

class SocketService extends ChangeNotifier {
  AuthService _auth;
  ContextService? _contextService;
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _lastToken;

  SocketService(this._auth, [this._contextService]) {
    _lastToken = _auth.token;
    _initSocket();
  }

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  void setContextService(ContextService service) {
    _contextService = service;
  }

  void updateAuth(AuthService auth, [ContextService? contextService]) {
    _auth = auth;
    if (contextService != null) {
      _contextService = contextService;
    }
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

  void connect() {
    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
    } else if (_socket == null && _auth.token != null) {
      _initSocket();
    }
  }

  void disconnect() {
    if (_socket != null && _socket!.connected) {
      _socket!.disconnect();
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
          .setAuth({
            'token': 'Bearer $token',
            'platform': AuthService.cachedPlatform,
            'appVersion': AuthService.cachedAppVersion,
          })
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
      if (err?.toString().contains('APP_UPDATE_REQUIRED') == true) {
        UpdateGateController.instance.require(UpdatePolicyInfo(
          state: UpdatePolicyState.requiredBlocking,
          clientVersion: AuthService.cachedAppVersion,
          minVersion: '0.0.0',
          recommendedVersion: '0.0.0',
          storeUrl: '',
          message: 'A mandatory app update is required to maintain realtime connection.',
        ));
      }
    });

    // Real-time Context Invalidation events (R14)
    _socket!.on('context:invalidated', (data) {
      if (data is Map && _contextService != null) {
        final scope = data['scope']?.toString();
        // R14: Jitter broadcast scopes (0-5s) so not all clients hit /sync concurrently
        if (scope == 's' || scope == 'o') {
          final jitterMs = Random().nextInt(5000);
          Future.delayed(Duration(milliseconds: jitterMs), () {
            _contextService?.triggerSync();
          });
        } else {
          _contextService?.triggerSync();
        }
      }
    });

    // Real-time Context Inline Slices (R14)
    _socket!.on('context:inline', (data) {
      if (data is Map<String, dynamic> && _contextService != null) {
        _contextService!.applyDelta(data);
      }
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
