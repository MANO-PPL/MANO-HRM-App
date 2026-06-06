import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';
import '../models/notification_model.dart';
import 'auth_service.dart';
import 'socket_service.dart';
import 'local_notification_service.dart';
import '../widgets/toast_helper.dart';

class NotificationService extends ChangeNotifier {
  final Dio _dio;
  final AuthService _authService;
  SocketService? _socketService;
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _registeredUserId;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Returns all notifications (role filtering bypassed per user request).
  List<NotificationModel> get filteredNotifications => _notifications;

  bool _fcmInitialized = false;
  String? _fcmToken;
  String _fcmPermissionStatus = 'Unknown';

  String? get fcmToken => _fcmToken;
  String get fcmPermissionStatus => _fcmPermissionStatus;
  bool get fcmInitialized => _fcmInitialized;

  // Track processed notification IDs to prevent duplicates between Socket and FCM
  final Set<int> _processedNotificationIds = {};
  IO.Socket? _lastSubscribedSocket;

  NotificationService(this._authService, [this._socketService]) : _dio = _authService.dio {
    initializeFCM();
    _listenToSocket();
  }

  bool _isDuplicate(int? id) {
    if (id == null || id == 0) return false;
    if (_processedNotificationIds.contains(id)) {
      return true;
    }
    _processedNotificationIds.add(id);
    if (_processedNotificationIds.length > 100) {
      _processedNotificationIds.remove(_processedNotificationIds.first);
    }
    return false;
  }

  // ── Static navigation helper ──────────────────────────────────────────────

  /// Called from:
  ///  • [main.dart] `LocalNotificationService.onNotificationTap` (foreground/background tap)
  ///  • [initializeFCM] `onMessageOpenedApp` (background FCM tap)
  ///  • [initializeFCM] `getInitialMessage` (killed-state FCM tap)
  ///
  /// Navigates the user to the Notifications section of the dashboard.
  static void handleNotificationNavigation() {
    // Give the UI a moment to settle if the app was just woken up
    Future.delayed(const Duration(milliseconds: 500), () {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      // Pop everything back to the root (DashboardScreen) first
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    });
  }

  // ── FCM Initialisation ────────────────────────────────────────────────────

  Future<void> initializeFCM() async {
    if (_fcmInitialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permissions (Android 13+ requires explicit prompt)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Suppress default foreground system notifications (off-app ones) on iOS when app is open
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      _fcmPermissionStatus = settings.authorizationStatus.name;
      notifyListeners();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM: Permission granted — ${settings.authorizationStatus}');

        // On iOS, wait for APNs token to be ready before calling getToken()
        if (Platform.isIOS) {
          int retries = 0;
          String? apnsToken;
          while (retries < 10) {
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
            debugPrint('FCM: APNs token not ready yet. Retrying in 1s...');
            await Future.delayed(const Duration(seconds: 1));
            retries++;
          }
          if (apnsToken == null) {
            debugPrint('FCM Warning: APNs token is null. FCM token registration might fail.');
          } else {
            debugPrint('FCM: APNs token is ready: $apnsToken');
          }
        }

        // Get & register token
        final token = await messaging.getToken();
        if (token != null) {
          _fcmToken = token;
          debugPrint('FCM Token: $token');
          await _registerFCMTokenOnServer(token);
          notifyListeners();
        }

        // Listen for token refreshes
        messaging.onTokenRefresh.listen((newToken) async {
          _fcmToken = newToken;
          debugPrint('FCM Token Refreshed: $newToken');
          await _registerFCMTokenOnServer(newToken);
          notifyListeners();
        });
      } else {
        debugPrint('FCM: User declined notification permissions.');
      }

      // ── Foreground messages ─────────────────────────────────────────────
      // When the app is open, FCM does NOT show a system notification automatically.
      // We use flutter_local_notifications to show a heads-up banner, just like WhatsApp.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground: ${message.notification?.title}');

        final rawId = message.data['notification_id'] ?? message.data['notificationId'] ?? message.data['id'];
        final int? notifId = rawId != null ? int.tryParse(rawId.toString()) : null;

        if (notifId != null && _isDuplicate(notifId)) {
          debugPrint('FCM Foreground: Ignoring duplicate notification ID $notifId (already handled by socket)');
          return;
        }

        final notifType = (message.data['type'] ?? 'info').toString().trim().toLowerCase();

        // Refresh in-app notification list
        fetchNotifications(refresh: true);

        final title = message.notification?.title ?? message.data['title'] ?? 'MANO';
        final body = message.notification?.body ?? message.data['body'] ?? '';

        // Show a heads-up banner via flutter_local_notifications
        if (title.isNotEmpty || body.isNotEmpty) {
          LocalNotificationService.showNotification(
            title: title,
            body: body,
            data: message.data,
            id: notifId ?? 0,
          );
        }

        // Also show an in-app dropdown banner for immediate awareness (refer WhatsApp/Instagram style)
        final ctx = navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          ctx.showInAppNotification(
            title: title,
            body: body,
            type: notifType,
            onTap: () {
              handleNotificationNavigation();
            },
          );
        }
      });

      // ── Background tap (app was suspended, user tapped the notification) ─
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: App opened from background via notification tap');
        fetchNotifications(refresh: true);
        handleNotificationNavigation();
      });

      // ── Killed-state tap (app was fully closed, user tapped the notification) ─
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM: App launched from killed state via notification tap');
        // Wait for app to fully initialise, then navigate
        Future.delayed(const Duration(seconds: 1), () {
          fetchNotifications(refresh: true);
          handleNotificationNavigation();
        });
      }

      _fcmInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FCM: Error initializing: $e');
    }
  }

  // ── Token Registration ────────────────────────────────────────────────────

  Future<void> _registerFCMTokenOnServer(String token) async {
    if (!_authService.isAuthenticated) {
      debugPrint('FCM: User not authenticated, skipping token registration.');
      return;
    }
    final userId = _authService.user?.id;
    if (_registeredUserId == userId) {
      debugPrint('FCM: Token already registered for current user.');
      return;
    }
    try {
      final response = await _dio.post(
        ApiConstants.notificationRegisterFCM,
        data: {
          'token': token,
          'device_type': Platform.isIOS ? 'ios' : 'android',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _registeredUserId = userId;
        debugPrint('FCM: Token registered with backend successfully.');
      } else {
        debugPrint('FCM: Failed to register token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FCM: Failed to register token with backend: $e');
    }
  }

  Future<void> _fetchAndRegisterToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      if (Platform.isIOS) {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('FCM: iOS APNs Token not ready yet during fetch.');
          return;
        }
      }

      final token = await messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        debugPrint('FCM Token fetched: $token');
        await _registerFCMTokenOnServer(token);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FCM: Error fetching token: $e');
    }
  }

  // ── Test helper ───────────────────────────────────────────────────────────

  Future<void> testPushNotification() async {
    try {
      final response = await _dio.post('/notifications/test-push');
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        if (response.statusCode == 200) {
          ctx.showToast('Test push notification requested!', isSuccess: true);
        } else {
          ctx.showToast('Failed: ${response.statusCode}', isError: true);
        }
      }
    } catch (e) {
      debugPrint('FCM: Error triggering test push: $e');
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.showToast('Error requesting test push: $e', isError: true);
      }
    }
  }

  // ── Notification fetching ─────────────────────────────────────────────────

  Future<void> fetchNotifications({bool refresh = false}) async {
    // Initialise FCM if not yet done (e.g. first call after login)
    if (_authService.isAuthenticated && !_fcmInitialized) {
      initializeFCM();
    } else if (_authService.isAuthenticated) {
      final userId = _authService.user?.id;
      if (_fcmToken != null) {
        if (_registeredUserId != userId) {
          await _registerFCMTokenOnServer(_fcmToken!);
        }
      } else if (_fcmInitialized) {
        await _fetchAndRegisterToken();
      }
    }
    // NOTE: We no longer re-register the token on every fetchNotifications call.
    // Token registration only happens once in initializeFCM and on token refresh.

    if (_isLoading && !refresh) return;
    
    _isLoading = true;
    if (refresh) notifyListeners(); // Show spinner only on explicit refresh

    try {
      final response = await _dio.get(
        ApiConstants.notifications, 
        queryParameters: {'limit': 50},
      );

      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
         final List list = response.data['data'] ?? response.data['notifications'] ?? [];
         _notifications = list.map((e) => NotificationModel.fromJson(e)).toList();
         // Count all unread notifications (role filtering bypassed per user request)
         _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Read helpers ──────────────────────────────────────────────────────────

  Future<void> markAsRead(int notificationId) async {
    try {
      // Optimistic Update
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          isRead: true,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }

      await _dio.put(ApiConstants.notificationMarkRead.replaceAll(':id', notificationId.toString()));
    } catch (e) {
       debugPrint('Error marking notification read: $e');
    }
  }

  Future<void> markAllAsRead() async {
     try {
       // Optimistic Update
       _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true, 
          createdAt: n.createdAt,
       )).toList();
       
       _unreadCount = 0;
       notifyListeners();

       await _dio.put(ApiConstants.notificationsReadAll);
     } catch (e) {
       debugPrint('Error marking all notifications read: $e');
     }
  }

  // ── Socket Notification Integration ──────────────────────────────────────

  void updateAuthAndSocket(AuthService auth, SocketService socket) {
    _socketService = socket;
    
    if (!auth.isAuthenticated) {
      // Clear cached values on logout so next login triggers registration
      _registeredUserId = null;
    } else {
      // Recheck / update token registration if auth changed
      final userId = auth.user?.id;
      if (_fcmToken != null) {
        if (_registeredUserId != userId) {
          _registerFCMTokenOnServer(_fcmToken!);
        }
      } else {
        // Authenticated but no token, try fetching
        if (_fcmInitialized) {
          _fetchAndRegisterToken();
        }
      }
    }
    _listenToSocket();
  }

  void _listenToSocket() {
    final socket = _socketService?.socket;
    if (socket == null) {
      _lastSubscribedSocket = null;
      return;
    }
    if (_lastSubscribedSocket == socket) {
      return; // Already listening to this socket
    }

    _lastSubscribedSocket?.off('new-notification');
    _lastSubscribedSocket?.off('new_notification');

    _lastSubscribedSocket = socket;

    debugPrint('🔌 NotificationService: Subscribing to socket notification events');
    socket.on('new-notification', _handleSocketNotification);
    socket.on('new_notification', _handleSocketNotification);
  }

  void _handleSocketNotification(dynamic data) {
    debugPrint('🔌 NotificationService: Received socket notification: $data');
    if (data == null) return;
    try {
      Map<String, dynamic> json;
      if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final newNotif = NotificationModel.fromJson(json);



      if (_isDuplicate(newNotif.id)) {
        debugPrint('🔌 NotificationService: Ignoring duplicate socket notification ID ${newNotif.id}');
        return;
      }

      _notifications.insert(0, newNotif);

      if (!newNotif.isRead) {
        _unreadCount++;
      }
      notifyListeners();

      final title = newNotif.title;
      final body = newNotif.message;

      // Show local notification banner via flutter_local_notifications
      LocalNotificationService.showNotification(
        title: title,
        body: body,
        id: newNotif.id,
        data: json,
      );

      // Show in-app dropdown banner (refer WhatsApp/Instagram style)
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.showInAppNotification(
          title: title,
          body: body,
          type: newNotif.type,
          onTap: () {
            handleNotificationNavigation();
          },
        );
      }
    } catch (e) {
      debugPrint('Error handling socket notification: $e');
    }
  }
}
