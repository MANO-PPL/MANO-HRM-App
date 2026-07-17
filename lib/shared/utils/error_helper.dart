import 'dart:io';
import 'package:dio/dio.dart';

/// Converts raw exceptions (DioException, SocketException, etc.) into
/// friendly, user-facing messages that do NOT expose backend URLs,
/// stack traces, or internal error details.
String friendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your internet connection and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please try again later.';
      case DioExceptionType.cancel:
        return 'Request was cancelled. Please try again.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        // Try to get the backend's user-friendly message if it's a map
        if (data is Map) {
          final msg = data['message'] ?? data['error'] ?? data['msg'];
          if (msg != null && msg is String && msg.isNotEmpty) {
            final lower = msg.toLowerCase();
            if (lower.contains('token') || lower.contains('expired') || lower.contains('unauthorized') || lower.contains('forbidden')) {
              return '$msg. Please log out and log in again to resolve this.';
            }
            return msg;
          }
        }
        // Map common HTTP status codes to user messages
        return switch (statusCode) {
          400 => 'Invalid request. Please check your input and try again.',
          401 => 'Your session has expired. Please log out and log in again to resolve this.',
          403 => 'Access forbidden. Please log out and log in again to resolve this.',
          404 => 'The requested resource was not found.',
          408 => 'Request timed out. Please try again.',
          409 => 'A conflict occurred. Please refresh and try again.',
          422 => 'Invalid data submitted. Please check your input.',
          429 => 'Too many requests. Please wait a moment and try again.',
          500 => 'The server encountered an error. Please try again later.',
          502 => 'Service temporarily unavailable. Please try again later.',
          503 => 'Service is currently unavailable. Please try again later.',
          504 => 'Server took too long to respond. Please try again.',
          _ => fallback,
        };
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return 'No internet connection. Please check your network and try again.';
        }
        return fallback;
    }
  }

  if (error is SocketException) {
    return 'No internet connection. Please check your network and try again.';
  }

  // For strings and other exception types, inspect the string representation
  final raw = error is Exception 
      ? error.toString().replaceFirst('Exception: ', '') 
      : error.toString();

  // If the message looks like a URL or contains raw technical details, don't show it
  if (raw.contains('http') ||
      raw.contains('://') ||
      raw.contains('SocketException') ||
      raw.contains('DioException') ||
      raw.contains('HandshakeException') ||
      raw.contains('FormatException') ||
      raw.contains('TypeError') ||
      raw.contains('NullThrownError') ||
      raw.contains('NoSuchMethodError') ||
      raw.contains('DatabaseException') ||
      raw.contains('OS Error') ||
      raw.contains('sql') ||
      raw.contains('database') ||
      raw.contains('query') ||
      raw.contains('select') ||
      raw.contains('insert') ||
      raw.contains('update') ||
      raw.contains('delete') ||
      raw.contains('stack trace') ||
      raw.contains('Stacktrace') ||
      raw.contains('Internal Server Error')) {
    return fallback;
  }

  // If it's reasonably short and human-readable, use it
  if (raw.length < 200 && !raw.contains('\n') && raw.trim().isNotEmpty) {
    final clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower.contains('token') || lower.contains('expired') || lower.contains('unauthorized') || lower.contains('forbidden')) {
      return '$clean. Please log out and log in again to resolve this.';
    }
    return clean;
  }

  return fallback;
}

/// Whether an error is caused by network connectivity issues.
bool isNetworkError(Object error) {
  if (error is DioException) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException);
  }
  return error is SocketException;
}

/// Automatically cleans and simplifies raw error messages before showing them to users.
String sanitizeErrorMessage(String message) {
  final lower = message.toLowerCase();
  
  // Extract clean part from common prefixes
  String content = message;
  final prefixes = [
    'failed: ',
    'error: ',
    'failed to delete: ',
    'camera error: ',
    'camera/location error: ',
    'upload failed: ',
    'assignment failed: ',
    'failed to save template: ',
    'failed to restore employee: ',
    'failed to permanently delete: ',
    'failed to update status: ',
  ];
  
  for (final prefix in prefixes) {
    if (lower.startsWith(prefix)) {
      content = message.substring(prefix.length);
      break;
    }
  }

  final cleanContent = friendlyError(content, fallback: 'Something went wrong. Please try again.');
  
  if (cleanContent == 'Something went wrong. Please try again.') {
    if (lower.startsWith('failed to delete: ') || lower.startsWith('failed to permanently delete: ')) {
      return 'Failed to delete. Please try again.';
    } else if (lower.startsWith('camera error: ') || lower.startsWith('camera/location error: ')) {
      return 'Camera or location error. Please try again.';
    } else if (lower.startsWith('upload failed: ')) {
      return 'Upload failed. Please check the file and try again.';
    } else if (lower.startsWith('failed to update status: ')) {
      return 'Failed to update status. Please try again.';
    } else if (lower.startsWith('assignment failed: ')) {
      return 'Failed to assign location. Please try again.';
    } else if (lower.startsWith('failed to restore employee: ')) {
      return 'Failed to restore employee. Please try again.';
    } else if (lower.startsWith('failed to save template: ')) {
      return 'Failed to save template. Please try again.';
    }
    return 'An error occurred. Please try again.';
  }
  
  // Re-attach prefix if appropriate and not redundant
  if (lower.startsWith('failed to delete: ') && !cleanContent.toLowerCase().startsWith('failed')) {
    return 'Failed to delete: $cleanContent';
  } else if (lower.startsWith('camera error: ') && !cleanContent.toLowerCase().startsWith('camera')) {
    return 'Camera error: $cleanContent';
  } else if (lower.startsWith('camera/location error: ') && !cleanContent.toLowerCase().startsWith('camera')) {
    return 'Camera or location error: $cleanContent';
  } else if (lower.startsWith('upload failed: ') && !cleanContent.toLowerCase().startsWith('upload')) {
    return 'Upload failed: $cleanContent';
  } else if (lower.startsWith('failed to update status: ') && !cleanContent.toLowerCase().startsWith('failed')) {
    return 'Failed to update status: $cleanContent';
  } else if (lower.startsWith('assignment failed: ') && !cleanContent.toLowerCase().startsWith('assignment')) {
    return 'Assignment failed: $cleanContent';
  }
  
  return cleanContent;
}
