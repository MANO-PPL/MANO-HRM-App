import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'features/dashboard/dashboard_screen.dart';
import 'features/auth/login_screen.dart'; // Import new LoginScreen
import 'shared/providers/theme_simple.dart';
import 'shared/widgets/orientation_guard.dart';
import 'shared/services/auth_service.dart';

import 'shared/services/notification_service.dart';
import 'shared/services/dashboard_provider.dart'; 
import 'features/attendance/providers/attendance_provider.dart';
import 'features/leave/providers/leave_provider.dart';
import 'features/leave/services/leave_service.dart'; // Import LeaveService
import 'shared/services/permission_service.dart'; // Import PermissionService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure Edge-to-Edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Request Permissions on Launch
  final permissionService = PermissionService();
  await permissionService.requestInitialPermissions();

  final authService = AuthService();
  await authService.init();

  final notificationService = NotificationService(authService);
  // Optional: Start fetching notifications immediately if auth is ready, 
  // but usually better to wait for auth check in AuthWrapper.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<DashboardProvider>(create: (_) => DashboardProvider(authService)),
        ChangeNotifierProxyProvider<AuthService, AttendanceProvider>(
          create: (context) => AttendanceProvider(context.read<AuthService>()),
          update: (context, auth, previous) => previous ?? AttendanceProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, LeaveProvider>(
          create: (context) => LeaveProvider(context.read<AuthService>()),
          update: (context, auth, previous) => previous ?? LeaveProvider(auth),
        ),
        ProxyProvider<AuthService, LeaveService>(
          update: (_, auth, __) => LeaveService(auth.dio),
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
        return MaterialApp(
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
      scaffoldBackgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
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
        backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
      textTheme: GoogleFonts.poppinsTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme
      ).apply(
        bodyColor: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0D1117),
        displayColor: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF0D1117),
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
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Check auth status (Refresh -> Get User)
    await authService.checkAuthStatus();
    
    // If authenticated, fetch notifications
    if (authService.isAuthenticated && mounted) {
      Provider.of<NotificationService>(context, listen: false).fetchNotifications();
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Watch for auth changes
    final isAuthenticated = context.watch<AuthService>().isAuthenticated;

    if (isAuthenticated) {
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
