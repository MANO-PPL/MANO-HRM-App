import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/api_constants.dart';
import '../widgets/toast_helper.dart';
import '../utils/error_helper.dart';
import 'network_monitor.dart';

import '../models/user_model.dart';
import 'package:http_parser/http_parser.dart'; // For MediaType
import 'package:mime/mime.dart'; // If available, or manually check extensions
import 'package:http/http.dart' as http; // For MultipartRequest
import 'dart:convert'; // For jsonDecode
import 'mail_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const MethodChannel _settingsChannel = MethodChannel('co.mano.attendance/settings');

class AuthService extends ChangeNotifier {
  final Dio _dio = Dio();
  late PersistCookieJar _cookieJar;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _accessToken;
  User? _currentUser;

  bool get isAuthenticated => _accessToken != null;
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
      storage: FileStorage("$appDocPath/.cookies/"),
    );

    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.interceptors.add(CookieManager(_cookieJar));

    _isInitialized = true;

    // Load saved token & user profile (always persist session on mobile, matching Attendance-Web behavior)
    _accessToken = await _storage.read(key: 'access_token');
    final cachedUser = await _storage.read(key: 'user');
    if (cachedUser != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(cachedUser));
      } catch (e) {
        debugPrint("Error decoding cached user: $e");
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

    // Setup Interceptor for Access Token & Refresh Logic
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Check for network connectivity or slow network issues
          // NetworkMonitor handles "offline" toasts globally; only show here for
          // timeout issues (slow network) or if NetworkMonitor hasn't fired yet.
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
            // Only show if NetworkMonitor thinks we're online (avoids duplicate toasts)
            _showNetworkToast(
              "No internet connection. Please check your Wi-Fi or mobile data.",
              isSlow: false,
            );
          }

          // Handle 401 Unauthorized & 403 Forbidden (likely expired access token)
          if ((e.response?.statusCode == 403 ||
                  e.response?.statusCode == 401) &&
              _accessToken != null) {
            try {
              final newAccessToken = await refreshToken();
              if (newAccessToken != null) {
                final opts = e.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';
                final clonedReq = await _dio.request(
                  opts.path,
                  options: Options(
                    method: opts.method,
                    headers: opts.headers,
                    contentType: opts.contentType,
                    responseType: opts.responseType,
                  ),
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                );
                return handler.resolve(clonedReq);
              } else {
                // Refresh failed without throwing, force logout
                await logout();
              }
            } catch (refreshError) {
              if (refreshError is DioException) {
                final status = refreshError.response?.statusCode;
                if (status == 401 || status == 403) {
                  // Only force logout if the backend explicitly rejected the refresh token (401/403)
                  await logout();
                } else {
                  debugPrint("Refresh failed due to network/server error ($status). Keeping session intact.");
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

  Future<Map<String, dynamic>> login(
    String userInput,
    String password,
    String captchaId,
    String captchaValue, {
    bool rememberMe = false,
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

        // Save rememberMe preference
        await _storage.write(
          key: 'remember_me',
          value: rememberMe ? 'true' : 'false',
        );

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
      // The cookie is automatically sent by Dio
      final response = await _dio.post(ApiConstants.refresh);

      if (response.statusCode == 200) {
        final newToken = response.data['accessToken'];
        if (newToken != null) {
          _accessToken = newToken;
          await _storage.write(key: 'access_token', value: newToken);
          return newToken;
        }
      }
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
          debugPrint("Refresh failed: Session Expired (403/401)");
        } else {
          debugPrint(
            "Refresh failed with status ${e.response?.statusCode}: ${e.message}",
          );
        }
      } else {
        debugPrint("Refresh failed: $e");
      }
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } catch (e) {
      // Ignore errors during logout
    } finally {
      _accessToken = null;
      _currentUser = null;
      await _cookieJar.deleteAll();
      await _storage.deleteAll();
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

  Future<Map<String, dynamic>?> checkAuthStatus() async {
    if (!NetworkMonitor().isOnline) {
      debugPrint("Offline: Skipping auth status check. Keeping existing session.");
      if (_currentUser != null) {
        return {'user': _currentUser!};
      }
      return null;
    }
    try {
      // Mimic React's initAuth: Try refresh first
      final newToken = await refreshToken();
      if (newToken != null) {
        // If refresh successful, fetch user details
        final user = await getMe();
        return user != null ? {'user': user} : null;
      }
    } catch (e) {
      debugPrint("Check auth status failed: $e");
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 401 || status == 403) {
          await logout();
        }
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
              data['avatar_url'] ?? data['user']?['profile_image_url'];

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
