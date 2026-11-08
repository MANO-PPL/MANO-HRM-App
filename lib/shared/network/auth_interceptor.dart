import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/constants/auth_error_codes.dart';
import 'package:flutter_application/shared/services/auth_storage_service.dart';
import 'package:flutter_application/shared/services/device_info_service.dart';
import 'package:flutter_application/shared/utils/error_helper.dart';
import 'package:flutter_application/shared/utils/error_logger.dart';
import 'package:flutter_application/shared/services/network_monitor.dart';

/// Dio QueuedInterceptor handling automatic header injection, per-device identity,
/// and queued token refresh on 401 Unauthorized responses.
class AuthInterceptor extends QueuedInterceptor {
  final Dio mainDio;
  final Dio refreshDio;
  final AuthStorageService storage;
  final DeviceInfoService deviceInfo;

  final void Function(String newToken)? onTokenRefreshed;
  final void Function(String message)? onSessionRevoked;
  final void Function(String message)? onSessionExpired;
  final void Function(String message)? onAccountInactive;
  final void Function(String message, {bool isSlow})? onNetworkIssue;

  AuthInterceptor({
    required this.mainDio,
    required this.refreshDio,
    required this.storage,
    required this.deviceInfo,
    this.onTokenRefreshed,
    this.onSessionRevoked,
    this.onSessionExpired,
    this.onAccountInactive,
    this.onNetworkIssue,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Ensure Device Info is initialized
    await deviceInfo.init();

    // 2. Attach Required Transport Headers
    options.headers['X-Client-Type'] = 'mobile';
    options.headers['X-App-Version'] = deviceInfo.appVersion;
    options.headers['X-Device-Id'] = deviceInfo.deviceId;
    options.headers['X-Device-Name'] = deviceInfo.deviceName;

    // 3. Attach Bearer Access Token if not suppressed
    if (options.extra['no_auth_header'] != true &&
        !options.headers.containsKey('Authorization')) {
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Diagnostic logging
    ErrorLogger.logApiError(err, contextTag: 'api_interceptor');

    // Network connectivity notifications
    final isOnline = NetworkMonitor().isOnline;
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      onNetworkIssue?.call(
        isOnline
            ? "Server is taking too long to respond. Please try again shortly."
            : "Slow or unstable connection. Please check your internet and try again.",
        isSlow: true,
      );
    } else if (err.type == DioExceptionType.connectionError ||
        err.error is SocketException) {
      onNetworkIssue?.call(
        isOnline
            ? "Server is currently unreachable. Please check if the backend server is running."
            : "No internet connection. Please check your Wi-Fi or mobile data.",
        isSlow: false,
      );
    }

    final path = err.requestOptions.path;
    final statusCode = err.response?.statusCode;

    // Guard: Do not attempt refresh on auth endpoints or retry loops
    final isRefreshRoute = path.contains(ApiConstants.refresh);
    final isExcludedAuthRoute = path.contains(ApiConstants.login) ||
        path.contains(ApiConstants.logout) ||
        path.contains(ApiConstants.notificationUnregisterFCM) ||
        err.requestOptions.extra['no_auth_refresh'] == true;
    final isRetry = err.requestOptions.headers['X-Retry'] == 'true';

    // Handle 401 Unauthorized via Queued Token Refresh
    if (statusCode == 401 && !isRefreshRoute && !isExcludedAuthRoute && !isRetry) {
      if (!NetworkMonitor().isOnline) {
        debugPrint("AuthInterceptor: Offline, skipping refresh attempt.");
        return handler.next(err);
      }

      final currentRefreshToken = await storage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        debugPrint("AuthInterceptor: No refresh token in storage. Aborting refresh.");
        return handler.next(err);
      }

      try {
        debugPrint("AuthInterceptor: 401 received. Initiating queued token refresh...");
        
        // Execute refresh using dedicated refreshDio to avoid interceptor recursion
        final refreshResponse = await refreshDio.post(
          ApiConstants.refresh,
          data: {'refreshToken': currentRefreshToken},
          options: Options(
            headers: {
              'X-Client-Type': 'mobile',
              'X-App-Version': deviceInfo.appVersion,
              'X-Device-Id': deviceInfo.deviceId,
              'X-Device-Name': deviceInfo.deviceName,
            },
            extra: {'no_auth_refresh': true, 'no_auth_header': true},
          ),
        );

        if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
          final resData = refreshResponse.data;
          final newAccessToken = resData['accessToken']?.toString();
          final newRefreshToken = resData['refreshToken']?.toString() ?? currentRefreshToken;
          final rawSid = resData['sessionId'];
          final sessionId = rawSid is int ? rawSid : (int.tryParse(rawSid?.toString() ?? '') ?? 0);

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await storage.saveAuthData(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
              sessionId: sessionId,
            );

            onTokenRefreshed?.call(newAccessToken);
            debugPrint("AuthInterceptor: Token refreshed successfully. Retrying request.");

            // Clone and retry original request with new access token
            final retryOptions = err.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
            retryOptions.headers['X-Retry'] = 'true';

            final clonedResponse = await mainDio.fetch(retryOptions);
            return handler.resolve(clonedResponse);
          }
        }
      } on DioException catch (refreshErr) {
        final refreshStatus = refreshErr.response?.statusCode;
        final resData = refreshErr.response?.data;
        final errorCode = resData is Map ? resData['code']?.toString() : null;

        debugPrint("AuthInterceptor: Refresh failed ($refreshStatus - $errorCode)");

        // 1. Session Revoked (from Web or Password Change)
        if (errorCode == AuthErrorCodes.sessionRevoked) {
          await storage.clearAuthData();
          onSessionRevoked?.call("Your session was signed out from another device.");
          return handler.next(refreshErr);
        }

        // 2. Account or Org Inactive -> Keep session intact, do NOT wipe storage
        if (errorCode == AuthErrorCodes.accountInactive ||
            errorCode == AuthErrorCodes.orgInactive) {
          final message = resData is Map && resData['message'] != null
              ? resData['message'].toString()
              : "Your account is inactive. Please contact HR.";
          onAccountInactive?.call(message);
          return handler.next(refreshErr);
        }

        // 3. Permanent Invalidation / Expired / Deleted
        if (errorCode == AuthErrorCodes.sessionExpired ||
            errorCode == AuthErrorCodes.invalidRefreshToken ||
            errorCode == AuthErrorCodes.accountDeleted ||
            errorCode == AuthErrorCodes.orgDeleted) {
          await storage.clearAuthData();
          onSessionExpired?.call("Session expired. Please log in again.");
          return handler.next(refreshErr);
        }

        // 4. Server error or transient issue -> Keep session intact
        debugPrint("AuthInterceptor: Transient refresh failure. Preserving credentials.");
        return handler.next(refreshErr);
      } catch (unknownErr) {
        debugPrint("AuthInterceptor: Unexpected refresh error: $unknownErr");
        return handler.next(err);
      }
    }

    final friendly = friendlyError(err);
    final friendlyException = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: friendly,
      message: friendly,
    );
    return handler.next(friendlyException);
  }
}
