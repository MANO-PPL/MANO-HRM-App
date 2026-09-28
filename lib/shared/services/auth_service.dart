import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/utils/error_helper.dart';
import 'package:flutter_application/shared/utils/error_logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_application/shared/services/network_monitor.dart';

import 'package:flutter_application/shared/models/user_model.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:mime/mime.dart'; // If available, or manually check extensions
import 'package:http/http.dart' as http; // For MultipartRequest
import 'dart:convert'; // For jsonDecode
import 'package:flutter_application/shared/services/mail_service.dart';
import 'package:flutter_application/shared/widgets/chatbot_fab.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const MethodChannel _settingsChannel = MethodChannel('co.mano.attendance/settings');

class AuthService extends ChangeNotifier {
  final Dio _dio = Dio();
  late PersistCookieJar _cookieJar;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static Future<String?> getSavedIdentifier() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'saved_identifier') ?? await storage.read(key: 'saved_email');
  }

  static Future<bool> getRememberMePreference() async {
    return true;
  }

  String? _accessToken;
  User? _currentUser;

  static const Set<String> _explicitRevokeCodes = {
    'INVALID_REFRESH_TOKEN',
    'TOKEN_REUSE_DETECTED',
    'SESSION_EXPIRED',
    'ACCOUNT_INACTIVE',
    'ACCOUNT_DELETED',
    'ORG_DELETED',
  };

  /// Returns true only when the server explicitly confirms the session/user is permanently invalidated.
  static bool _isExplicitSessionRevocation(int? statusCode, String? errorCode) {
    return (statusCode == 401 || statusCode == 403) &&
        errorCode != null &&
        _explicitRevokeCodes.contains(errorCode);
  }

  // Future lock to synchronize concurrent token refreshes
  Future<String?>? _refreshFuture;

  bool _isLoggingOut = false;

  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  User? get user => _currentUser;
  String? get token => _accessToken;

  bool _isInitialized = false;

  DateTime? _lastNetworkToastTime;

  void _showNetworkToast(String message, {bool isSlow = false}) {
    final now = DateTime.now();
    if (_lastNetworkToastTime != null &&
        now.difference(_lastNetworkToastTime!).inSeconds < 5) {
      return;
    }
    _lastNetworkToastTime = now;

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      context.showToast(
        message,
        isWarning: isSlow,
        isError: !isSlow,
        actionLabel: isSlow ? null : "SETTINGS",
        onActionPressed: isSlow
            ? null
            : () async {
                if (Platform.isAndroid) {
                  try {
                    await _settingsChannel.invokeMethod('openNetworkSettings');
                  } catch (e) {
                    await openAppSettings();
                  }
                } else {
                  await openAppSettings();
                }
              },
      );
    }
  }

  // Initialize AuthService
  Future<void> init() async {
    if (_isInitialized) return;

    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    _cookieJar = PersistCookieJar(
      persistSession: true,
      ignoreExpires: true,
      storage: FileStorage("$appDocPath/.cookies/"),
    );

    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.interceptors.add(CookieManager(_cookieJar));

    _isInitialized = true;

    // Load saved tokens & user profile (always persist session on mobile, matching Attendance-Web behavior)
    _accessToken = await _storage.read(key: 'access_token');
    final savedRefreshToken = await _readRefreshTokenWithDiagnostics();
    final cachedUser = await _storage.read(key: 'user');
    if (cachedUser != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(cachedUser));
      } catch (e) {
        debugPrint("Error decoding cached user: $e");
        _currentUser = null;
      }
    }

    // Proactively sync saved refresh token into CookieJar on startup
    if (savedRefreshToken != null && savedRefreshToken.isNotEmpty) {
      await _syncRefreshTokenCookie(savedRefreshToken);
    }

    // Initialize and start the singleton NetworkMonitor
    final networkMonitor = NetworkMonitor();
    await networkMonitor.init();

    // Listen for offline/online transitions and show proper toasts
    networkMonitor.addListener(() {
      if (!networkMonitor.isOnline) {
        _showNetworkToast(
          "No internet connection. Please check your Wi-Fi or mobile data.",
          isSlow: false,
        );
      } else {
        // Network restored — show a brief success toast
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          context.showToast(
            "Connection restored. Refreshing data…",
            isSuccess: true,
          );
        }
      }
    });

    // Setup Interceptor for Access Token & Refresh Logic
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null && options.extra['no_auth_header'] != true) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Log network or api errors locally on device with sensitive credentials scrubbed
          ErrorLogger.logApiError(
            e,
            contextTag: 'api_interceptor',
          );

          // Check for network connectivity or slow network issues
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            _showNetworkToast(
              "Slow or unstable connection. Please check your internet and try again.",
              isSlow: true,
            );
          } else if ((e.type == DioExceptionType.connectionError ||
                  e.error is SocketException) &&
              NetworkMonitor().isOnline) {
            _showNetworkToast(
              "No internet connection. Please check your Wi-Fi or mobile data.",
              isSlow: false,
            );
          }

          final path = e.requestOptions.path;

          // Guard 1: Avoid recursive refresh loops if the failed request is refresh, logout, fcm unregister, or suppressed
          final isRefreshRequest = path.contains(ApiConstants.refresh);
          final isLogoutOrCleanupRequest = path.contains(ApiConstants.logout) ||
              path.contains(ApiConstants.notificationUnregisterFCM) ||
              path.contains(ApiConstants.login) ||
              e.requestOptions.extra['no_auth_refresh'] == true;

          // Guard 2: Avoid infinite loops on genuine permission errors (e.g. 403 Forbidden retry fails again)
          final isRetry = e.requestOptions.headers['X-Retry'] == 'true';

          // Handle 401 Unauthorized (likely expired access token)
          if (e.response?.statusCode == 401 &&
              !_isLoggingOut &&
              !isRefreshRequest &&
              !isLogoutOrCleanupRequest &&
              !isRetry) {
            try {
              // Await synchronized refresh future to avoid race conditions
              final newAccessToken = await _synchronizedRefreshToken();
              if (newAccessToken != null) {
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';
                // Tag as retry to prevent loops if endpoint remains restricted
                opts.headers['X-Retry'] = 'true';

                final clonedReq = await _dio.request(
                  opts.path,
                  options: Options(
                    method: opts.method,
                    headers: opts.headers,
                    contentType: opts.contentType,
                    responseType: opts.responseType,
                    extra: opts.extra,
                  ),
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                );
                return handler.resolve(clonedReq);
              }
            } catch (refreshError) {
              if (refreshError is DioException) {
                final status = refreshError.response?.statusCode;
                final resData = refreshError.response?.data;
                final errorCode = resData is Map ? resData['code']?.toString() : null;

                if (_isExplicitSessionRevocation(status, errorCode)) {
                  // Only force logout if the backend explicitly rejected the refresh token
                  debugPrint("Backend explicitly rejected session ($status - $errorCode). Logging out.");
                  await logout();
                } else {
                  debugPrint("Refresh failed ($status - $errorCode). Keeping session intact without revoking server token.");
                }
              } else {
                debugPrint("Refresh failed due to unexpected error ($refreshError). Keeping session intact.");
              }
            }
          }
          final friendly = friendlyError(e);
          final friendlyException = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: friendly,
            message: friendly,
          );
          return handler.next(friendlyException);
        },
      ),
    );
  }

  /// Extracts the refresh token from response data or Set-Cookie header.
  String? _extractRefreshToken(Response response) {
    if (response.data is Map && response.data['refreshToken'] != null) {
      final token = response.data['refreshToken'].toString().trim();
      if (token.isNotEmpty) return token;
    }
    final rawCookies = response.headers['set-cookie'];
    if (rawCookies != null) {
      for (final cookieStr in rawCookies) {
        final match = RegExp(r'refreshToken=([^;]+)').firstMatch(cookieStr);
        if (match != null && match.group(1) != null) {
          final token = match.group(1)!.trim();
          if (token.isNotEmpty) return token;
        }
      }
    }
    return null;
  }

  /// Programmatically injects the refresh token cookie into the PersistCookieJar.
  Future<void> _syncRefreshTokenCookie(String token) async {
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final cookie = Cookie('refreshToken', token)
        ..domain = uri.host
        ..path = '/'
        ..httpOnly = true
        ..secure = uri.scheme == 'https'
        ..maxAge = 30 * 24 * 60 * 60; // 30 Days (matches backend REFRESH_TOKEN_COOKIE_MAX_AGE)
      await _cookieJar.saveFromResponse(uri, [cookie]);
      debugPrint("AuthService: Refresh token synced to CookieJar for ${uri.host}");
    } catch (e) {
      debugPrint("AuthService: Error syncing refresh token cookie: $e");
    }
  }

  /// Safely reads the refresh token from FlutterSecureStorage with diagnostic logging.
  /// If FlutterSecureStorage returns null/empty or throws an exception, falls back to
  /// checking the CookieJar which already persists the session cookie in the app sandbox.
  Future<String?> _readRefreshTokenWithDiagnostics() async {
    String? token;
    try {
      token = await _storage.read(key: 'refresh_token');
      if (token != null && token.isNotEmpty) {
        debugPrint("AuthService: Refresh token read from SecureStorage (length: ${token.length})");
        return token;
      }
    } catch (e, stack) {
      debugPrint("AuthService: SecureStorage exception reading refresh_token: $e\n$stack");
      await ErrorLogger.logError(
        e,
        type: 'secure_storage_exception',
        extraInfo: {
          'action': 'read_refresh_token',
          'error': e.toString(),
          'stack': stack.toString(),
        },
      );
    }

    // Fallback: Check CookieJar for the 'refreshToken' cookie
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final cookies = await _cookieJar.loadForRequest(uri);
      for (final cookie in cookies) {
        if (cookie.name == 'refreshToken' && cookie.value.isNotEmpty) {
          debugPrint("AuthService: Found candidate refresh token in CookieJar fallback.");
          await ErrorLogger.logError(
            'Candidate refresh token loaded from CookieJar fallback',
            type: 'auth_recovery',
            extraInfo: {'source': 'cookie_jar_fallback'},
          );
          return cookie.value;
        }
      }
    } catch (cookieErr) {
      debugPrint("AuthService: CookieJar fallback check error: $cookieErr");
    }

    debugPrint("AuthService: No refresh token found in SecureStorage or CookieJar.");
    await ErrorLogger.logError(
      'refresh_token is NULL or empty across all storages',
      type: 'auth_diagnostic',
      extraInfo: {'action': 'read_refresh_token', 'result': 'NULL'},
    );
    return null;
  }

  /// Wrapper around refreshToken that ensures only one active network call 
  /// is made to the backend refresh endpoint at a time.
  Future<String?> _synchronizedRefreshToken() async {
    if (_refreshFuture != null) {
      debugPrint("Token refresh already in progress. Awaiting existing request...");
      return _refreshFuture;
    }

    _refreshFuture = refreshToken();
    try {
      final newToken = await _refreshFuture;
      return newToken;
    } finally {
      _refreshFuture = null; // Clear lock
    }
  }

  Future<Map<String, dynamic>> login(
    String userInput,
    String password,
    String captchaId,
    String captchaValue, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'user_input': userInput,
          'user_password': password,
          'captchaId': captchaId,
          'captchaText': captchaValue,
          'rememberMe': rememberMe,
        },
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['accessToken'];
        await _storage.write(key: 'access_token', value: _accessToken);

        // Save refresh token permanently (matches 30-day sliding session in Attendance-Web)
        final refreshTokenStr = _extractRefreshToken(response);
        if (refreshTokenStr != null && refreshTokenStr.isNotEmpty) {
          await _storage.write(key: 'refresh_token', value: refreshTokenStr);
          await _syncRefreshTokenCookie(refreshTokenStr);
          debugPrint("AuthService: Saved refresh token permanently on login.");
        }

        // Save rememberMe preference
        await _storage.write(
          key: 'remember_me',
          value: rememberMe ? 'true' : 'false',
        );

        if (rememberMe) {
          await _storage.write(key: 'saved_identifier', value: userInput);
        } else {
          await _storage.delete(key: 'saved_identifier');
          await _storage.delete(key: 'saved_email');
        }

        // 1. Initial Data (Login): Store complete profile info from login response
        // Best for: Initial Dashboard Load
        if (response.data['user'] != null) {
          _currentUser = User.fromJson(response.data['user']);
          await _storage.write(
            key: 'user',
            value: jsonEncode(_currentUser!.toJson()),
          );
        } else {
          // Fallback if user object missing (unlikely per docs)
          await getMe();
        }

        notifyListeners(); // Notify UI
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Login Failed');
      }
    } catch (e) {
      if (e is DioException &&
          e.response?.data != null &&
          e.response!.data is Map) {
        throw Exception(e.response!.data['message'] ?? 'Login Failed');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCaptcha() async {
    try {
      final response = await _dio.get(ApiConstants.captchaGenerate);
      return response.data;
    } catch (e) {
      debugPrint("Detailed Captcha Error: $e");
      throw Exception(friendlyError(e, fallback: 'Unable to load captcha. Please try again.'));
    }
  }

  Future<String?> refreshToken() async {
    if (!NetworkMonitor().isOnline) {
      debugPrint("Offline: Skipping refreshToken API call. Returning current token.");
      return _accessToken;
    }
    try {
      final savedRefreshToken = await _readRefreshTokenWithDiagnostics();
      if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
        debugPrint("AuthService: No local refresh token available. Skipping /auth/refresh API call to prevent false 401.");
        return null;
      }

      await _syncRefreshTokenCookie(savedRefreshToken);

      final response = await _dio.post(
        ApiConstants.refresh,
        data: {'refreshToken': savedRefreshToken},
        options: Options(
          headers: {'x-refresh-token': savedRefreshToken},
          extra: {'no_auth_refresh': true, 'no_auth_header': true},
        ),
      );

      if (response.statusCode == 200) {
        final newToken = response.data['accessToken'];
        if (newToken != null) {
          _accessToken = newToken;
          await _storage.write(key: 'access_token', value: newToken);

          // Update refresh token if rotated / extended
          final updatedRefreshToken =
              _extractRefreshToken(response) ?? savedRefreshToken;
          if (updatedRefreshToken.isNotEmpty) {
            await _storage.write(key: 'refresh_token', value: updatedRefreshToken);
            await _syncRefreshTokenCookie(updatedRefreshToken);
            debugPrint("AuthService: Extended refresh token in storage & CookieJar.");
          }
          return newToken;
        }
      }
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        final resData = e.response?.data;
        final errorCode = resData is Map ? resData['code']?.toString() : null;
        debugPrint("Refresh failed with status $status, code: $errorCode, message: ${e.message}");
        await ErrorLogger.logApiError(e, contextTag: 'token_refresh');
      } else {
        debugPrint("Refresh failed: $e");
        await ErrorLogger.logError(e, type: 'token_refresh_exception');
      }
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    // Immediately remove any floating chatbot overlay
    ChatbotOverlayManager.destroyAll();

    final savedToken = _accessToken;

    // Immediately clear in-memory auth state to prevent 401 refresh loops from any ongoing requests
    _accessToken = null;
    _currentUser = null;

    try {
      // Unregister FCM token from the backend (best effort)
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && savedToken != null) {
        await _dio.post(
          ApiConstants.notificationUnregisterFCM,
          data: {'token': token},
          options: Options(
            headers: {
              'Authorization': 'Bearer $savedToken',
              'X-Retry': 'true',
            },
            extra: {'no_auth_refresh': true, 'no_auth_header': true},
          ),
        );
        debugPrint('FCM: Token unregistered on logout successfully.');
      }
    } catch (e) {
      debugPrint('FCM: Failed to unregister token on logout: $e');
    }

    try {
      final savedRefreshToken = await _storage.read(key: 'refresh_token');
      if (savedToken != null || savedRefreshToken != null) {
        await _dio.post(
          ApiConstants.logout,
          data: savedRefreshToken != null ? {'refreshToken': savedRefreshToken} : null,
          options: Options(
            headers: {
              if (savedToken != null) 'Authorization': 'Bearer $savedToken',
              if (savedRefreshToken != null) 'x-refresh-token': savedRefreshToken,
              'X-Retry': 'true',
            },
            extra: {'no_auth_refresh': true, 'no_auth_header': true},
          ),
        );
      }
    } catch (e) {
      // Ignore errors during logout
    } finally {
      // Preserve remember me & saved identifier across logouts
      final rememberMe = await _storage.read(key: 'remember_me');
      final savedIdentifier = await _storage.read(key: 'saved_identifier') ?? await _storage.read(key: 'saved_email');

      try {
        await _cookieJar.deleteAll();
      } catch (e) {
        debugPrint("Error clearing cookie jar: $e");
      }
      try {
        await _storage.deleteAll();
        if (rememberMe != null) {
          await _storage.write(key: 'remember_me', value: rememberMe);
        }
        if (savedIdentifier != null && rememberMe != 'false') {
          await _storage.write(key: 'saved_identifier', value: savedIdentifier);
        }
      } catch (e) {
        debugPrint("Error clearing secure storage: $e");
      }
      ChatbotOverlayManager.destroyAll();
      _isLoggingOut = false;
      notifyListeners(); // Notify UI to redirect
    }
  }

  // Forgot Password Flow
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      debugPrint(
        'Sending OTP request to: ${ApiConstants.baseUrl}${ApiConstants.forgotPassword}',
      );
      debugPrint('Email: $email');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.forgotPassword}',
        data: {'email': email},
      );

      debugPrint('OTP request successful: ${response.data}');
      return response.data;
    } catch (e) {
      debugPrint('Forgot password error: $e');
      if (e is DioException) {
        debugPrint('Response status: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');

        // Check if backend failed to send email (500 error)
        if (e.response?.statusCode == 500 &&
            e.response?.data != null &&
            e.response!.data is Map &&
            e.response!.data['message']?.toString().contains(
                  'Failed to send email',
                ) ==
                true) {
          debugPrint(
            'Backend email service failed. Attempting Flutter email fallback...',
          );

          // Check if backend provided OTP in error response
          if (e.response!.data['otp'] != null) {
            final otp = e.response!.data['otp'].toString();
            debugPrint('OTP received from backend: $otp');

            // Try to send email via Flutter
            final mailService = MailService();
            final emailSent = await mailService.sendPasswordResetOtp(
              recipientEmail: email,
              otp: otp,
            );

            if (emailSent) {
              debugPrint('OTP email sent successfully via Flutter fallback');
              return {'message': 'OTP sent to your email'};
            } else {
              throw Exception(
                'Failed to send OTP email. Please check your email configuration.',
              );
            }
          } else {
            // Backend didn't provide OTP, can't proceed
            throw Exception(
              'Backend email service is unavailable. Please contact support.',
            );
          }
        }

        if (e.response?.data != null && e.response!.data is Map) {
          throw Exception(e.response!.data['message'] ?? 'Failed to send OTP');
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      debugPrint('Verifying OTP for: $email');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.verifyOtp}',
        data: {'email': email, 'otp': otp},
      );

      debugPrint('OTP verification successful');
      return response.data;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      if (e is DioException) {
        debugPrint('Response status: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');
        if (e.response?.data != null && e.response!.data is Map) {
          throw Exception(e.response!.data['message'] ?? 'Invalid OTP');
        }
      }
      rethrow;
    }
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    try {
      debugPrint('Resetting password with token');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.resetPassword}',
        data: {'resetToken': resetToken, 'newPassword': newPassword},
      );

      debugPrint('Password reset successful');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.data['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      debugPrint('Password reset error: $e');
      if (e is DioException) {
        debugPrint('Response status: ${e.response?.statusCode}');
        debugPrint('Response data: ${e.response?.data}');
        if (e.response?.data != null && e.response!.data is Map) {
          throw Exception(
            e.response!.data['message'] ?? 'Failed to reset password',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> changePassword(String newPassword) async {
    try {
      final response = await _dio.post(
        ApiConstants.changePassword,
        data: {'newPassword': newPassword},
      );
      if (response.statusCode == 200) {
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(forcePasswordChange: false);
          await _storage.write(
            key: 'user',
            value: jsonEncode(_currentUser!.toJson()),
          );
          notifyListeners();
        }
      } else {
        throw Exception(response.data['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      if (e is DioException &&
          e.response?.data != null &&
          e.response!.data is Map) {
        throw Exception(
          e.response!.data['message'] ?? 'Failed to change password',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> checkAuthStatus() async {
    if (!NetworkMonitor().isOnline) {
      debugPrint("Offline: Skipping auth status check. Keeping existing session.");
      if (_currentUser != null) {
        return {'user': _currentUser!};
      }
      return null;
    }

    final savedRefreshToken = await _readRefreshTokenWithDiagnostics();
    if (_accessToken == null && savedRefreshToken == null) {
      return null;
    }

    try {
      // Mimic React's initAuth: Try refresh first
      final newToken = await refreshToken();
      if (newToken != null) {
        // If refresh successful, fetch user details
        final user = await getMe();
        return user != null
            ? {'user': user}
            : (_currentUser != null ? {'user': _currentUser!} : null);
      } else if (_currentUser != null) {
        debugPrint("AuthService: Token refresh skipped/null, but cached user exists. Retaining session.");
        return {'user': _currentUser!};
      }
    } catch (e) {
      debugPrint("Check auth status failed: $e");
      if (e is DioException) {
        final status = e.response?.statusCode;
        final resData = e.response?.data;
        final errorCode = resData is Map ? resData['code']?.toString() : null;

        // Only force logout if the backend explicitly rejected the refresh token as invalid/revoked
        if (_isExplicitSessionRevocation(status, errorCode)) {
          debugPrint("Backend explicitly rejected session on checkAuth ($status - $errorCode). Logging out.");
          await logout();
          return null;
        }
      }
      // On temporary 403, server errors, or network drops, retain cached session
      if (_currentUser != null) {
        debugPrint("AuthService: Retaining session despite error: $e");
        return {'user': _currentUser!};
      }
    }
    return null;
  }

  // 3. Session/Dashboard Refresh
  // Best for: Verifying Session & Basic Info
  Future<User?> getMe() async {
    try {
      final response = await _dio.get(ApiConstants.me);
      if (response.statusCode == 200) {
        final newUserPartial = User.fromJson(response.data);

        // Merge with existing to preserve fields like phone/designation if missing in /auth/me
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            id: newUserPartial.id.isNotEmpty
                ? newUserPartial.id
                : _currentUser!.id,
            name: newUserPartial.name,
            username: newUserPartial.username.isNotEmpty
                ? newUserPartial.username
                : _currentUser!.username,
            email: newUserPartial.email,
            role: newUserPartial.role,
            profileImage: newUserPartial.profileImage,
            // Preserve if null in partial response
            phone: newUserPartial.phone ?? _currentUser!.phone,
            department: newUserPartial.department ?? _currentUser!.department,
            designation:
                newUserPartial.designation ?? _currentUser!.designation,
            forcePasswordChange: newUserPartial.forcePasswordChange,
          );
        } else {
          _currentUser = newUserPartial;
        }

        await _storage.write(
          key: 'user',
          value: jsonEncode(_currentUser!.toJson()),
        );

        notifyListeners();
        return _currentUser;
      }
    } catch (e) {
      debugPrint("GetMe failed: $e");
    }
    return null;
  }

  // 2. Fetch Full Profile (Profile Page)
  // Best for: User Profile Page
  Future<User?> fetchUserProfile() async {
    try {
      final response = await _dio.get(ApiConstants.profileMe);
      if (response.statusCode == 200 && response.data['ok'] == true) {
        final profileUser = User.fromJson(response.data['user']);

        // Merge logic
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            name: profileUser.name,
            email: profileUser.email,
            phone: profileUser.phone, // "phone_no" from API maps to this
            role: profileUser.role, // "user_type"
            designation: profileUser.designation, // "desg_name"
            department: profileUser.department, // "dept_name"
            profileImage: profileUser.profileImage,
            // "user_code" might be missing in profile API, verify
            username: profileUser.username.isNotEmpty
                ? profileUser.username
                : _currentUser!.username,
          );
        } else {
          _currentUser = profileUser;
        }

        await _storage.write(
          key: 'user',
          value: jsonEncode(_currentUser!.toJson()),
        );

        notifyListeners();
        return _currentUser;
      }
    } catch (e) {
      debugPrint("Fetch Profile Failed: $e");
    }
    return _currentUser;
  }

  // Update Profile Picture (Using http package as requested for compatibility)
  Future<void> updateProfilePicture(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      debugPrint('Uploading profile pic to $uri using http package');

      final request = http.MultipartRequest('POST', uri);

      // Headers
      request.headers.addAll({
        'Accept': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      });

      // MimeType Detection
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final mimeSplit = mimeType.split('/');

      debugPrint('Uploading file: ${imageFile.path} ($mimeType)');

      // File
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          imageFile.path,
          contentType: MediaType(mimeSplit[0], mimeSplit[1]),
        ),
      );

      // Send
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Upload Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['ok'] == true) {
          final newAvatarUrl =
              data['profile_image_url'] ?? data['avatar_url'] ?? data['user']?['profile_image_url'];

          if (newAvatarUrl != null) {
            // Immediate Local Update
            if (_currentUser != null) {
              _currentUser = _currentUser!.copyWith(profileImage: newAvatarUrl);
              await _storage.write(
                key: 'user',
                value: jsonEncode(_currentUser!.toJson()),
              );
              notifyListeners();
            } else {
              await getMe();
            }
          } else {
            await fetchUserProfile();
          }
        }
      } else {
        throw Exception('Avatar upload failed: ${response.body}');
      }
    } catch (e) {
      debugPrint("HTTP Upload Error: $e");
      rethrow;
    }
  }

  // Delete Profile Picture
  Future<void> deleteProfilePicture() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}');
      debugPrint('Deleting profile pic at $uri');

      final response = await http.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        },
      );

      debugPrint('Delete Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        // Immediate Local Update
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(
            profileImage: null,
          ); // Clear image
          await _storage.write(
            key: 'user',
            value: jsonEncode(_currentUser!.toJson()),
          );
          notifyListeners();
        } else {
          await getMe();
        }
      } else {
        throw Exception('Failed to delete profile picture: ${response.body}');
      }
    } catch (e) {
      debugPrint("HTTP Delete Error: $e");
      rethrow;
    }
  }

  // Expose Dio client for other services to reuse auth headers/interceptors
  Dio get dio => _dio;
}

// [upd:2026-04-29T09:00:00+05:30]

// [upd:2026-05-08T09:00:00+05:30]

// [upd:2026-05-13T17:00:00+05:30]
