import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_application/features/dashboard/dashboard_screen.dart';
import 'package:flutter_application/features/auth/login_screen.dart'; // Import new LoginScreen
import 'package:flutter_application/features/auth/views/force_password_change_screen.dart';
import 'package:flutter_application/shared/providers/theme_simple.dart';
import 'package:flutter_application/shared/widgets/orientation_guard.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/services/network_monitor.dart';
import 'package:flutter_application/shared/services/in_app_update_service.dart';

import 'package:flutter_application/shared/services/notification_service.dart';
import 'package:flutter_application/shared/services/local_notification_service.dart';
import 'package:flutter_application/shared/services/dashboard_provider.dart';
import 'package:flutter_application/features/attendance/providers/attendance_provider.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import 'package:flutter_application/features/leave/services/leave_service.dart'; // Import LeaveService
import 'package:flutter_application/shared/services/permission_service.dart'; // Import PermissionService
import 'package:flutter_application/shared/services/chatbot_service.dart'; // Import ChatbotService
import 'package:flutter_application/shared/services/socket_service.dart';
import 'package:flutter_application/features/collaboration/services/chat_service.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must re-initialise Firebase in the background isolate
  await Firebase.initializeApp();
  debugPrint('FCM background message received: ${message.messageId}');

  // Eagerly initialize local notification settings inside the background isolate
  await LocalNotificationService.initialize();

  // Only display a local notification if the message does not contain a notification payload
  // AND the data payload explicitly provides a non-empty title (indicating a custom data-only notification).
  // This prevents displaying duplicate or empty/meaningless notifications (e.g., "MANO" with no body)
  // when Android background isolates receive notification messages where message.notification is parsed as null.
  if (message.notification == null) {
    final dataTitle = message.data['title'];
    final dataBody = message.data['body'];
    if (dataTitle != null && dataTitle.toString().trim().isNotEmpty) {
      await LocalNotificationService.showNotification(
        title: dataTitle.toString(),
        body: dataBody?.toString() ?? '',
        data: message.data,
      );
    }
  }
}

void main() async {
  Provider.debugCheckInvalidValueType = null;
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background handler BEFORE any other FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await LocalNotificationService.initialize(
    onNotificationTap: (response) {
      // Foreground / resumed-from-background tap:
      // Navigate to notifications screen via the global navigator key.
      Map<String, dynamic>? data;
      if (response.payload != null) {
        try {
          data = jsonDecode(response.payload!) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error parsing notification payload: $e');
        }
      }
      NotificationService.handleNotificationNavigation(data);
    },
  );

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Configure Edge-to-Edge
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Request Permissions on Launch
  final permissionService = PermissionService();
  await permissionService.requestInitialPermissions();

  final authService = AuthService();
  await authService.init();

  // Optional: Start fetching notifications immediately if auth is ready,
  // but usually better to wait for auth check in AuthWrapper.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<NetworkMonitor>.value(value: NetworkMonitor()),
        ChangeNotifierProxyProvider<AuthService, SocketService>(
          create: (context) => SocketService(context.read<AuthService>()),
          update: (context, auth, previous) {
            final service = previous ?? SocketService(auth);
            service.updateAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, SocketService, NotificationService>(
          create: (context) => NotificationService(
            context.read<AuthService>(),
            context.read<SocketService>(),
          ),
          update: (context, auth, socket, previous) {
            final service = previous ?? NotificationService(auth, socket);
            service.updateAuthAndSocket(auth, socket);
            return service;
          },
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (_) => DashboardProvider(authService),
        ),
        ChangeNotifierProxyProvider<AuthService, AttendanceProvider>(
          create: (context) => AttendanceProvider(context.read<AuthService>()),
          update: (context, auth, previous) =>
              previous ?? AttendanceProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, LeaveProvider>(
          create: (context) => LeaveProvider(context.read<AuthService>()),
          update: (context, auth, previous) => previous ?? LeaveProvider(auth),
        ),
        ProxyProvider<AuthService, LeaveService>(
          update: (_, auth, _) => LeaveService(auth.dio),
        ),
        ChangeNotifierProxyProvider<AuthService, ChatbotService>(
          create: (context) => ChatbotService(context.read<AuthService>()),
          update: (context, auth, previous) =>
              previous ?? ChatbotService(auth),
        ),
        ChangeNotifierProvider<ChatService>(
          create: (context) {
            final chatService = ChatService(context.read<AuthService>().dio);
            chatService.initializeSocketListening(context.read<SocketService>());
            return chatService;
          },
        ),
        Provider<PermissionService>.value(value: permissionService),
      ],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        final isDark = currentMode == ThemeMode.dark ||
            (currentMode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Admin Dashboard',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: currentMode,
          // Check for existing session or show login
          home: const AuthWrapper(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness, // Explicitly match the brightness
        seedColor: isDark ? const Color(0xFF2F81F7) : const Color(0xFF5B60F6),
        primary: isDark ? const Color(0xFF2F81F7) : const Color(0xFF5B60F6),

        surface: isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF),
        onSurface: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0D1117),
        secondary: isDark ? const Color(0xFF8D96A0) : const Color(0xFF64748B),
      ),
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF8FAFC),
      fontFamily: GoogleFonts.poppins().fontFamily,
      cardColor: isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? const Color(0xFF0D1117)
            : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
      textTheme:
          GoogleFonts.poppinsTextTheme(
            isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
          ).apply(
            bodyColor: isDark
                ? const Color(0xFFE6EDF3)
                : const Color(0xFF0D1117),
            displayColor: isDark
                ? const Color(0xFFE6EDF3)
                : const Color(0xFF0D1117),
          ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Force eager initialization of NotificationService to request FCM permissions and register token at startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NotificationService>(context, listen: false);
        // Check for app updates via Google Play Store
        InAppUpdateService.checkForUpdates(context);
      }
    });
    _checkAuth();
    // Register reconnect callback to reload data when network is restored
    NetworkMonitor().addReconnectCallback(_onNetworkReconnected);
  }

  @override
  void dispose() {
    NetworkMonitor().removeReconnectCallback(_onNetworkReconnected);
    super.dispose();
  }

  /// Called by NetworkMonitor whenever the device regains internet connectivity.
  void _onNetworkReconnected() {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated) {
      // Re-check auth status to ensure token is still valid
      authService.checkAuthStatus();
      // Refresh notifications
      context.read<NotificationService>().fetchNotifications();
      // Refresh chats
      context.read<ChatService>().getRooms();
      // Refresh dashboard data
      context.read<DashboardProvider>().fetchDashboardData(forceRefresh: true);
      // Refresh attendance records & policy & correction counts
      context.read<AttendanceProvider>().fetchRecords(DateTime.now(), forceRefresh: true);
      context.read<AttendanceProvider>().checkMissedPunch();
      context.read<AttendanceProvider>().fetchPendingCorrectionCount(userId: authService.user?.employeeId);
      // Refresh leaves (both personal history and admin pending requests)
      context.read<LeaveProvider>().fetchMyLeaves(forceRefresh: true);
      context.read<LeaveProvider>().fetchPendingRequests(forceRefresh: true);
    }
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check auth status (Refresh -> Get User)
    await authService.checkAuthStatus();

    // If authenticated, fetch notifications and chats
    if (authService.isAuthenticated && mounted) {
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).fetchNotifications();
      Provider.of<ChatService>(
        context,
        listen: false,
      ).getRooms();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen(message: "Initializing MANO...");
    }

    // Watch for auth changes
    final authService = context.watch<AuthService>();
    final isAuthenticated = authService.isAuthenticated;

    if (isAuthenticated) {
      final user = authService.user;
      if (user != null && user.forcePasswordChange) {
        return const OrientationGuard(
          key: ValueKey('force_password_change'),
          child: ForcePasswordChangeScreen(),
        );
      }
      return const OrientationGuard(
        key: ValueKey('auth_dashboard'),
        child: DashboardScreen(),
      );
    }

    // Use the new LoginScreen wrapped in OrientationGuard
    return const OrientationGuard(
      key: ValueKey('auth_login'),
      child: LoginScreen(),
    );
  }
}
