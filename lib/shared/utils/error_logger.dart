import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_application/shared/services/network_monitor.dart';

class ErrorLogger {
  static const String _logKey = 'app_error_logs';
  static const int _maxLogs = 100;

  static final RegExp _sensitiveKeyPattern = RegExp(
    r'(password|token|secret|auth|cookie|otp|key|credential|pin|captcha|bearer|session)',
    caseSensitive: false,
  );

  static final RegExp _jwtPattern = RegExp(
    r'eyJ[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}\.[a-zA-Z0-9_\-]{10,}',
  );

  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[a-zA-Z0-9_\-\.]+',
    caseSensitive: false,
  );

  /// Recursively scrubs sensitive credentials (passwords, tokens, cookies, auth headers)
  /// from any map, list, or string before saving or exporting.
  static dynamic sanitizeData(dynamic data, [String? keyName]) {
    if (data == null) return null;

    if (keyName != null && _sensitiveKeyPattern.hasMatch(keyName)) {
      return '[REDACTED]';
    }

    if (data is String) {
      String sanitized = data;
      if (_jwtPattern.hasMatch(sanitized)) {
        sanitized = sanitized.replaceAll(_jwtPattern, '[REDACTED_JWT]');
      }
      if (_bearerPattern.hasMatch(sanitized)) {
        sanitized = sanitized.replaceAll(_bearerPattern, 'Bearer [REDACTED]');
      }
      return sanitized;
    }

    if (data is Map) {
      final Map<String, dynamic> result = {};
      data.forEach((key, value) {
        final k = key.toString();
        if (_sensitiveKeyPattern.hasMatch(k)) {
          result[k] = '[REDACTED]';
        } else {
          result[k] = sanitizeData(value, k);
        }
      });
      return result;
    }

    if (data is List) {
      return data.map((item) => sanitizeData(item, keyName)).toList();
    }

    return data;
  }

  /// Sets up global Flutter framework error and async dispatcher hooks to catch
  /// uncaught client-side crashes, platform exceptions, and rendering errors.
  static void setupGlobalErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logError(
        details.exception,
        type: 'flutter_framework_error',
        stackTrace: details.stack,
        extraInfo: {
          'library': details.library ?? 'unknown',
          'context': details.context?.toDescription() ?? 'unspecified',
        },
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logError(
        error,
        type: 'unhandled_async_error',
        stackTrace: stack,
      );
      return true; // marked as handled
    };
  }

  /// Logs detailed API request failures with stripped sensitive information.
  static Future<void> logApiError(
    DioException e, {
    String contextTag = 'api_request',
    Map<String, dynamic>? extraInfo,
  }) async {
    try {
      final req = e.requestOptions;
      final res = e.response;

      // Extract endpoint path without query parameters that could leak tokens
      String cleanPath = req.path;
      try {
        final uri = Uri.parse(req.path);
        cleanPath = uri.path;
      } catch (_) {}

      dynamic backendCode;
      dynamic backendMessage;
      dynamic sanitizedResponseData;

      if (res?.data != null) {
        if (res!.data is Map) {
          final map = res.data as Map;
          backendCode = map['code'] ?? map['statusCode'] ?? map['status'];
          backendMessage = map['message'] ?? map['error'] ?? map['msg'];
          sanitizedResponseData = sanitizeData(map);
        } else if (res.data is String) {
          final str = res.data as String;
          if (str.length < 300) {
            sanitizedResponseData = sanitizeData(str);
          } else {
            sanitizedResponseData = '${str.substring(0, 300)}... [truncated]';
          }
        }
      }

      // Record request payload keys (NOT values) to confirm which fields were sent
      List<String>? requestPayloadKeys;
      if (req.data is Map) {
        requestPayloadKeys = (req.data as Map).keys.map((k) => k.toString()).toList();
      }

      final isOnline = NetworkMonitor().isOnline;

      final apiDetails = <String, dynamic>{
        'context_tag': contextTag,
        'endpoint': cleanPath,
        'method': req.method,
        'status_code': res?.statusCode,
        'status_message': res?.statusMessage,
        'dio_type': e.type.toString(),
        if (backendCode != null) 'backend_code': backendCode.toString(),
        if (backendMessage != null) 'backend_message': backendMessage.toString(),
        if (sanitizedResponseData != null) 'response_preview': sanitizedResponseData,
        if (requestPayloadKeys != null) 'request_payload_keys': requestPayloadKeys,
        'network_online': isOnline,
        if (extraInfo != null) ...sanitizeData(extraInfo) as Map<String, dynamic>,
      };

      await logError(
        e.error ?? e.message ?? 'DioException (${res?.statusCode ?? e.type})',
        type: cleanPath.contains('/auth') ? 'auth_api_error' : 'api_error',
        stackTrace: e.stackTrace,
        extraInfo: apiDetails,
      );
    } catch (loggingErr) {
      debugPrint("ErrorLogger: Failed to log API error: $loggingErr");
    }
  }

  static Future<void> logError(
    dynamic error, {
    String type = 'general',
    StackTrace? stackTrace,
    Map<String, dynamic>? extraInfo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> logs = await getErrors();

      StackTrace? effectiveStack = stackTrace;
      if (effectiveStack == null && error is Error) {
        effectiveStack = error.stackTrace;
      }

      final sanitizedExtra = extraInfo != null ? sanitizeData(extraInfo) : null;

      final newLog = {
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'message': sanitizeData(error?.toString() ?? 'Unknown Error'),
        'error_class': error.runtimeType.toString(),
        if (effectiveStack != null)
          'stack_trace': effectiveStack.toString().split('\n').take(12).join('\n'),
        'os': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        if (sanitizedExtra is Map<String, dynamic>) ...sanitizedExtra,
      };

      logs.insert(0, newLog);

      if (logs.length > _maxLogs) {
        logs.removeRange(_maxLogs, logs.length);
      }

      final List<String> encodedLogs = logs.map((l) => jsonEncode(l)).toList();
      await prefs.setStringList(_logKey, encodedLogs);
    } catch (e) {
      debugPrint('Failed to save log to shared_preferences: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? raw = prefs.getStringList(_logKey);
      if (raw == null) return [];
      
      return raw.map((item) {
        try {
          return jsonDecode(item) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      }).where((item) => item.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Failed to read logs from shared_preferences: $e');
      return [];
    }
  }

  static Future<void> clearErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
    } catch (e) {
      debugPrint('Failed to clear logs from shared_preferences: $e');
    }
  }

  static Future<void> exportErrors(BuildContext context) async {
    try {
      final List<Map<String, dynamic>> logs = await getErrors();
      if (logs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No diagnostic logs available to export.')),
          );
        }
        return;
      }

      final report = {
        'export_metadata': {
          'app_name': 'MANO HRM',
          'export_time': DateTime.now().toIso8601String(),
          'os': Platform.operatingSystem,
          'os_version': Platform.operatingSystemVersion,
          'total_entries': logs.length,
          'note': 'All sensitive credentials (passwords, tokens, auth headers) have been automatically redacted.',
        },
        'logs': logs,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(report);

      // Use platform-specific directory:
      // Android → public Downloads folder (visible in Files app)
      // iOS     → app Documents directory (accessible via Files app when UIFileSharingEnabled)
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getDownloadsDirectory() ?? await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find storage directory.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final String dateStr = DateTime.now().toIso8601String().split('T').first;
      final String timeStr = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String filePath = '${dir.path}/mano_diagnostics_${dateStr}_$timeStr.json';

      final File file = File(filePath);
      await file.writeAsString(jsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Diagnostic logs exported (${logs.length} entries)'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () => OpenFilex.open(filePath),
            ),
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
