import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/constants/auth_error_codes.dart';
import 'package:flutter_application/shared/services/auth_storage_service.dart';
import 'package:flutter_application/shared/services/device_info_service.dart';
import 'package:flutter_application/shared/network/auth_interceptor.dart';
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
  final Dio _refreshDio = Dio();
  late PersistCookieJar _cookieJar;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthStorageService _authStorage = AuthStorageService();
  final DeviceInfoService _deviceInfo = DeviceInfoService();

  static Future<String?> getSavedIdentifier() async {
    return await AuthStorageService().getSavedIdentifier();
  }

  static Future<bool> getRememberMePreference() async {
    return await AuthStorageService().getRememberMePreference();
  }

  String? _accessToken;
  User? _currentUser;

  static const Set<String> _explicitRevokeCodes = {
    AuthErrorCodes.invalidRefreshToken,
    'TOKEN_REUSE_DETECTED',
    AuthErrorCodes.sessionRevoked,
    AuthErrorCodes.sessionExpired,
    AuthErrorCodes.accountDeleted,
    AuthErrorCodes.orgDeleted,
  };

  /// Returns true only when the server explicitly confirms the session/user is permanently invalidated.
  static bool _isExplicitSessionRevocation(int? statusCode, String? errorCode) {
    return (statusCode == 401 || statusCode == 403) &&
        errorCode != null &&
        _explicitRevokeCodes.contains(errorCode);
  }


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

    // Initialize Device Identification
    await _deviceInfo.init();

    // Migrate any legacy cookie tokens into FlutterSecureStorage
    await _authStorage.migrateLegacyTokensIfNeeded(_cookieJar);

    // Main Dio configuration
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.sendTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.headers['Accept'] = 'application/json';

    // Dedicated Refresh Dio (isolated from main interceptors to avoid refresh recursion)
    _refreshDio.options.baseUrl = ApiConstants.baseUrl;
    _refreshDio.options.connectTimeout = const Duration(seconds: 15);
    _refreshDio.options.sendTimeout = const Duration(seconds: 15);
    _refreshDio.options.receiveTimeout = const Duration(seconds: 15);
    _refreshDio.options.headers['Content-Type'] = 'application/json';
    _refreshDio.options.headers['Accept'] = 'application/json';

    // Setup QueuedInterceptor for Automatic Headers, Device Telemetry & Synchronized Refresh
    _dio.interceptors.add(
      AuthInterceptor(
        mainDio: _dio,
        refreshDio: _refreshDio,
        storage: _authStorage,
        deviceInfo: _deviceInfo,
        onTokenRefreshed: (newToken) {
          _accessToken = newToken;
          notifyListeners();
        },
        onSessionRevoked: (msg) async {
          _showNetworkToast(msg, isSlow: false);
          await logout();
        },
        onSessionExpired: (msg) async {
          _showNetworkToast(msg, isSlow: false);
          await logout();
        },
        onAccountInactive: (msg) {
          // Do NOT logout user! Show notification and keep cached session intact.
          _showNetworkToast(msg, isSlow: false);
        },
        onNetworkIssue: (msg, {bool isSlow = false}) {
          _showNetworkToast(msg, isSlow: isSlow);
        },
      ),
    );

    _isInitialized = true;

    // Load saved tokens & user profile from AuthStorageService
    _accessToken = await _authStorage.getAccessToken();
    final cachedUser = await _authStorage.getCachedUserJson();
    if (cachedUser != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(cachedUser));
      } catch (e) {
        debugPrint("Error decoding cached user: $e");
        _currentUser = null;
      }
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
  }


  Future<Map<String, dynamic>> login(
    String userInput,
    String password,
    String captchaId,
    String captchaValue, {
    bool rememberMe = true,
  }) async {
    try {
      await _deviceInfo.init();

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

      if (response.statusCode == 200 && response.data != null) {
        _accessToken = response.data['accessToken'];
        final refreshTokenStr = response.data['refreshToken']?.toString();
        final rawSid = response.data['sessionId'];
        final sessionId = rawSid is int ? rawSid : (int.tryParse(rawSid?.toString() ?? '') ?? 0);

        if (_accessToken != null && refreshTokenStr != null && refreshTokenStr.isNotEmpty) {
          await _authStorage.saveAuthData(
            accessToken: _accessToken!,
            refreshToken: refreshTokenStr,
            sessionId: sessionId,
          );
          debugPrint("AuthService: Saved accessToken, refreshToken, and sessionId on login.");
        }

        // Save rememberMe preference
        await _authStorage.saveRememberMePreference(
          rememberMe: rememberMe,
          identifier: userInput,
        );

        if (response.data['user'] != null) {
          _currentUser = User.fromJson(response.data['user']);
          await _authStorage.saveCachedUserJson(
            jsonEncode(_currentUser!.toJson()),
          );
        } else {
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

  Future<String?>? _directRefreshFuture;

  Future<String?> refreshToken() async {
    if (_directRefreshFuture != null) {
      debugPrint("AuthService: Direct token refresh already in progress. Awaiting existing request...");
      return _directRefreshFuture;
    }
    _directRefreshFuture = _executeRefreshToken();
    try {
      return await _directRefreshFuture;
    } finally {
      _directRefreshFuture = null;
    }
  }

  Future<String?> _executeRefreshToken() async {
    if (!NetworkMonitor().isOnline) {
      debugPrint("Offline: Skipping refreshToken API call. Returning current token.");
      return _accessToken;
    }
    try {
      final savedRefreshToken = await _authStorage.getRefreshToken();
      if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
        debugPrint("AuthService: No local refresh token available. Skipping /auth/refresh API call to prevent false 401.");
        return null;
      }

      await _deviceInfo.init();

      // Explicit JSON Body Token Transport with Device Telemetry Headers
      final response = await _refreshDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': savedRefreshToken},
        options: Options(
          headers: {
            'X-Client-Type': 'mobile',
            'X-App-Version': _deviceInfo.appVersion,
            'X-Device-Id': _deviceInfo.deviceId,
            'X-Device-Name': _deviceInfo.deviceName,
          },
          extra: {'no_auth_refresh': true, 'no_auth_header': true},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data;
        final newToken = resData['accessToken']?.toString();
        final newRefreshToken = resData['refreshToken']?.toString() ?? savedRefreshToken;
        final rawSid = resData['sessionId'];
        final sessionId = rawSid is int ? rawSid : (int.tryParse(rawSid?.toString() ?? '') ?? 0);

        if (newToken != null && newToken.isNotEmpty) {
          _accessToken = newToken;
          await _authStorage.saveAuthData(
            accessToken: newToken,
            refreshToken: newRefreshToken,
            sessionId: sessionId,
          );
          notifyListeners();
          debugPrint("AuthService: Successfully refreshed access & sliding refresh token.");
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
    final savedRefreshToken = await _authStorage.getRefreshToken();

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
      if (savedRefreshToken != null && savedRefreshToken.isNotEmpty) {
        await _dio.post(
          ApiConstants.logout,
          data: {'refreshToken': savedRefreshToken},
          options: Options(
            headers: {
              if (savedToken != null) 'Authorization': 'Bearer $savedToken',
              'X-Retry': 'true',
            },
            extra: {'no_auth_refresh': true, 'no_auth_header': true},
          ),
        );
      }
    } catch (e) {
      debugPrint('Logout API error: $e');
    } finally {
      try {
        await _cookieJar.deleteAll();
      } catch (e) {
        debugPrint("Error clearing cookie jar: $e");
      }
      try {
        await _authStorage.clearAuthData();
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

    final savedRefreshToken = await _authStorage.getRefreshToken();
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

        // If account or org is inactive -> do NOT logout! Notify user and retain session
        if (errorCode == AuthErrorCodes.accountInactive ||
            errorCode == AuthErrorCodes.orgInactive) {
          debugPrint("Account or Org inactive on checkAuth ($status - $errorCode). Retaining session.");
          final msg = resData is Map && resData['message'] != null
              ? resData['message'].toString()
              : "Your account is currently inactive. Please contact HR.";
          _showNetworkToast(msg, isSlow: false);
          return _currentUser != null ? {'user': _currentUser!} : null;
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
