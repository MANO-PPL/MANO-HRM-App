import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../../shared/constants/api_constants.dart';
import '../../../../shared/models/shift_model.dart';
import '../models/attendance_record.dart';
import '../models/correction_request.dart';

class AttendanceService {
  final Dio _dio;
  static const MethodChannel _backgroundChannel = MethodChannel('co.mano.attendance/background');

  AttendanceService(this._dio);

  String _basenameWithoutExtension(String path) {
    final base = path.split('/').last.split('\\').last;
    final idx = base.lastIndexOf('.');
    return idx == -1 ? base : base.substring(0, idx);
  }

  // 0. Get the employee's assigned shift policy (correction deadline, timing, etc.)
  // Tries GET /employee/my-shift first; falls back to GET /policies/shifts[0]
  Future<Shift?> getMyShiftPolicy() async {
    try {
      final response = await _dio.get(ApiConstants.myShift);
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data['data'] ?? response.data;
        if (raw is Map<String, dynamic>) return Shift.fromJson(raw);
      }
    } catch (_) {
      // Endpoint may not exist yet; fall back to policyShifts
    }
    try {
      final response = await _dio.get(ApiConstants.policyShifts);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['data'];
        if (list is List && list.isNotEmpty) {
          return Shift.fromJson(list.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('getMyShiftPolicy fallback failed: $e');
    }
    return null;
  }

  // 1. Get My Records
  Future<List<AttendanceRecord>> getMyRecords({String? fromDate, String? toDate, String? userId, int? limit}) async {
    try {
      final response = await _dio.get(ApiConstants.attendanceRecords, queryParameters: {
        'date_from': fromDate,
        'date_to': toDate,
        if (userId != null) 'user_id': userId,
        if (limit != null) 'limit': limit,
      });

      if (response.statusCode == 200 && response.data['ok']) {
        final List<dynamic> list = response.data['data'];
        return list.map((json) => AttendanceRecord.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch records: $e');
    }
  }

  // 1.5 Get Admin Records
  Future<List<AttendanceRecord>> getAdminAttendanceRecords(String date) async {
    try {
      final response = await _dio.get(ApiConstants.adminAttendanceRecords, queryParameters: {
        'date_from': date,
        'date_to': date,
        'limit': 200, 
      });

      if (response.statusCode == 200 && response.data['ok']) {
        final List<dynamic> list = response.data['data'];
        return list.map((json) => AttendanceRecord.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch live records: $e');
    }
  }

  // 2. Time In
  Future<Map<String, dynamic>> timeIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    required File imageFile,
    String? lateReason,
    String? timestamp,
  }) async {
    try {
      try {
        await _backgroundChannel.invokeMethod('startBackgroundTask');
      } catch (e) {
        debugPrint("Failed to start background task: $e");
      }

      final fixedFile = await _fixOrientationAndCompress(imageFile);
      final fileName = '${_basenameWithoutExtension(imageFile.path)}.jpg';

      String? utcTimestamp;
      if (timestamp != null) {
        try {
          utcTimestamp = DateTime.parse(timestamp).toUtc().toIso8601String();
        } catch (_) {
          utcTimestamp = timestamp;
        }
      }

      FormData formData = FormData.fromMap({
        "latitude": latitude.toStringAsFixed(4),
        "longitude": longitude.toStringAsFixed(4),
        "accuracy": accuracy.toStringAsFixed(2),
        if (lateReason != null) "late_reason": lateReason,
        if (utcTimestamp != null) ...{
          "timestamp": utcTimestamp,
          "created_at": utcTimestamp,
          "time": utcTimestamp,
          "date": utcTimestamp,
          "time_in": utcTimestamp,
        },
        "image": await MultipartFile.fromFile(
          fixedFile.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      debugPrint("AttService: TimeIn upload size=${await fixedFile.length()} bytes (orientation-fixed JPEG)");
      debugPrint("AttService: TimeIn fields: ${formData.fields.map((e) => '${e.key}: ${e.value}')}");

      final response = await _dio.post(ApiConstants.attendanceTimeIn, data: formData);
      debugPrint("AttService: TimeIn Success: ${response.data}");
      return response.data;
    } catch (e) {
      throw _parseError(e);
    } finally {
      try {
        await _backgroundChannel.invokeMethod('endBackgroundTask');
      } catch (e) {
        debugPrint("Failed to end background task: $e");
      }
    }
  }

  // 3. Time Out
  Future<Map<String, dynamic>> timeOut({
    required double latitude,
    required double longitude,
    required double accuracy,
    required File imageFile,
    String? timestamp,
  }) async {
    try {
      try {
        await _backgroundChannel.invokeMethod('startBackgroundTask');
      } catch (e) {
        debugPrint("Failed to start background task: $e");
      }

      final fixedFile = await _fixOrientationAndCompress(imageFile);
      final fileName = '${_basenameWithoutExtension(imageFile.path)}.jpg';

      String? utcTimestamp;
      if (timestamp != null) {
        try {
          utcTimestamp = DateTime.parse(timestamp).toUtc().toIso8601String();
        } catch (_) {
          utcTimestamp = timestamp;
        }
      }

      FormData formData = FormData.fromMap({
        "latitude": latitude.toStringAsFixed(4),
        "longitude": longitude.toStringAsFixed(4),
        "accuracy": accuracy.toStringAsFixed(2),
        if (utcTimestamp != null) ...{
          "timestamp": utcTimestamp,
          "created_at": utcTimestamp,
          "time": utcTimestamp,
          "date": utcTimestamp,
          "time_out": utcTimestamp,
        },
        "image": await MultipartFile.fromFile(
          fixedFile.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      debugPrint("AttService: TimeOut upload size=${await fixedFile.length()} bytes (orientation-fixed JPEG)");

      final response = await _dio.post(ApiConstants.attendanceTimeOut, data: formData);
      return response.data;
    } catch (e) {
      throw _parseError(e);
    } finally {
      try {
        await _backgroundChannel.invokeMethod('endBackgroundTask');
      } catch (e) {
        debugPrint("Failed to end background task: $e");
      }
    }
  }

  // Fix EXIF orientation and compress before upload.
  // - Reads EXIF orientation and physically rotates pixels to match
  // - Caps longest side at 1280px (well under any nginx limit)
  // - Re-encodes as JPEG at 75% quality
  // - Strips EXIF so viewers don't re-apply rotation
  Future<File> _fixOrientationAndCompress(File imageFile) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        final originalSize = await imageFile.length();
        debugPrint('_fixOrientationAndCompress: input=$originalSize bytes path=${imageFile.path}');

        final tmpDir = await getTemporaryDirectory();
        final outPath = '${tmpDir.path}${Platform.pathSeparator}${_basenameWithoutExtension(imageFile.path)}_fixed.jpg';

        final result = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          outPath,
          minWidth: 1280,   // cap longest side — handles both portrait & landscape
          minHeight: 1280,  // flutter_image_compress scales proportionally to fit
          quality: 75,      // 75% JPEG: visually indistinguishable, ~200-500KB
          keepExif: false,  // bake orientation into pixels, strip EXIF tag
        );

        if (result != null) {
          final outFile = File(result.path);
          final compressedSize = await outFile.length();
          debugPrint(
            '_fixOrientationAndCompress: done — '
            '$originalSize bytes → $compressedSize bytes '
            '(${(compressedSize / 1024).toStringAsFixed(0)} KB)',
          );
          return outFile;
        }
      }
    } catch (e) {
      debugPrint("Image compression failed or platform not supported, using original file: $e");
    }
    return imageFile;
  }
  // 4. Correction Requests (New)

  // Submit Request (Employee)
  // proposed_data must be an array of sessions: [{time_in: "HH:MM:SS", time_out: "HH:MM:SS"}]
  Future<void> submitCorrectionRequest({
    required String requestDate, // YYYY-MM-DD
    required String correctionType, // correction, missed_punch, overtime, other
    required String correctionMethod, // add_session, reset, fix
    required String reason,
    required Map<String, dynamic> correctionData,
    double? latitude,
    double? longitude,
    List<dynamic>? attachments, // PlatformFile or File
  }) async {
    try {
      // Build proposed_data array from correctionData:
      // correctionData may have:
      //   sessions: [{time_in, time_out}]      (addSession method)
      //   requested_time_in / requested_time_out (reset/fix method)
      List<Map<String, String>> proposedData = [];

      if (correctionData['sessions'] != null && correctionData['sessions'] is List) {
        proposedData = (correctionData['sessions'] as List).map<Map<String, String>>((s) {
          final timeIn = (s['time_in'] ?? s['in'] ?? '').toString();
          final timeOut = (s['time_out'] ?? s['out'] ?? '').toString();
          return {'time_in': timeIn, 'time_out': timeOut};
        }).toList();
      } else if (correctionData['requested_time_in'] != null || correctionData['requested_time_out'] != null) {
        proposedData = [
          {
            'time_in': (correctionData['requested_time_in'] ?? '').toString(),
            'time_out': (correctionData['requested_time_out'] ?? '').toString(),
          }
        ];
      }

      final Map<String, dynamic> payload = {
        "request_date": requestDate,
        "correction_type": correctionType,
        "reason": reason,
        "original_data": [],
        "proposed_data": proposedData,
        if (latitude != null) "latitude": latitude,
        if (longitude != null) "longitude": longitude,
      };

      dynamic data = payload;

      // Handle Attachments via FormData
      if (attachments != null && attachments.isNotEmpty) {
        final formData = FormData.fromMap({
          "request_date": requestDate,
          "correction_type": correctionType,
          "reason": reason,
          if (latitude != null) "latitude": latitude,
          if (longitude != null) "longitude": longitude,
        });
        // Add sessions as indexed fields
        for (var i = 0; i < proposedData.length; i++) {
          formData.fields.add(MapEntry('proposed_data[$i][time_in]', proposedData[i]['time_in'] ?? ''));
          formData.fields.add(MapEntry('proposed_data[$i][time_out]', proposedData[i]['time_out'] ?? ''));
        }
        // Add files
        for (var attachment in attachments) {
          if (attachment.path != null) {
            formData.files.add(MapEntry(
              'attachments[]',
              await MultipartFile.fromFile(attachment.path!, filename: attachment.name),
            ));
          }
        }
        data = formData;
      }

      await _dio.post(ApiConstants.attendanceCorrectionRequest, data: data);
    } catch (e) {
      throw _parseError(e);
    }
  }

  // Fetch All Requests
  Future<List<AttendanceCorrectionRequest>> getCorrectionRequests({
    String? status, 
    String? userId, 
    String? date,
    int? month,
    int? year,
    int? page,
    int? limit,
    String? dateFrom, // Kept for backward compatibility if needed by other views
    String? dateTo,
  }) async {
    try {
      final response = await _dio.get(ApiConstants.attendanceCorrectionRequests, queryParameters: {
        if (status != null) 'status': status,
        if (userId != null) 'user_id': userId,
        if (date != null) 'date': date,
        if (month != null) 'month': month,
        if (year != null) 'year': year,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      });
      
      if (response.statusCode == 200 && response.data != null && response.data is Map) {
         final dynamic data = response.data['data'];
         if (data is List) {
           return data.map((json) => AttendanceCorrectionRequest.fromJson(json as Map<String, dynamic>)).toList();
         }
      }
      return [];
    } catch (e) {
      throw _parseError(e);
    }
  }
  
  // Get Request Detail
  Future<AttendanceCorrectionRequest> getCorrectionRequestDetail(String id) async {
    try {
      final response = await _dio.get('${ApiConstants.attendanceCorrectionRequest}/$id');
      if (response.statusCode == 200 && response.data != null && response.data is Map) {
        // Handle both wrapped {data: {...}} and unwrapped {...} responses
        final dynamic data = response.data['data'] ?? response.data;
        if (data is Map) {
          return AttendanceCorrectionRequest.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw Exception('Correction request not found or invalid response');
    } catch (e) {
      throw _parseError(e);
    }
  }

  // Process Request (Admin/HR Only)
  // Backend PATCH /attendance/correct-request/:acr_id expects:
  //   status: 'approved' | 'rejected'
  //   review_comments?: string
  //   sessions?: [{time_in, time_out}]  (admin override)
  Future<void> processCorrectionRequest(String id, {
    required String status, // approved, rejected
    String? reviewComments,
    String? overrideMethod,
    String? requestDate,
    List<Map<String, String>>? sessions, // admin override sessions
    String? resetTimeIn, // for building override session
    String? resetTimeOut, // for building override session
  }) async {
    try {
      // Build override sessions array if times are provided
      List<Map<String, String>>? overrideSessions = sessions;
      if (overrideSessions == null && resetTimeIn != null && resetTimeOut != null) {
        overrideSessions = [{'time_in': resetTimeIn, 'time_out': resetTimeOut}];
      }

      final payload = {
        "status": status,
        if (reviewComments != null && reviewComments.isNotEmpty) "review_comments": reviewComments,
        if (overrideSessions != null) "sessions": overrideSessions,
      };

      await _dio.patch('${ApiConstants.attendanceCorrectRequestUpdate}/$id', data: payload);
    } catch (e) {
      throw _parseError(e);
    }
  }
  
  // 5. Simulation (Dev Only)
  Future<void> simulateTimeIn(Map<String, dynamic> data) async {
      await _dio.post(ApiConstants.simulateTimeIn, data: FormData.fromMap(data));
  }
  
  Future<void> simulateTimeOut(Map<String, dynamic> data) async {
      await _dio.post(ApiConstants.simulateTimeOut, data: FormData.fromMap(data));
  }

  // 6. Export My Report
  Future<Uint8List> exportMyReport(String month) async {
    try {
      final response = await _dio.get(
        ApiConstants.attendanceRecordExport,
        queryParameters: {'month': month},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw _parseError(e);
    }
  }

  Exception _parseError(dynamic e) {
    if (e is DioException) {
      debugPrint("AttService Error: ${e.response?.statusCode} - ${e.response?.data}");
      final isNetwork = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.error is SocketException;
      
      String msg = e.message ?? e.toString();
      if (e.response?.data != null && e.response!.data is Map) {
        msg = e.response?.data['message'] ?? msg;
      }
      return AttendanceApiException(
        msg,
        statusCode: e.response?.statusCode,
        isNetworkError: isNetwork,
      );
    }
    return AttendanceApiException(e.toString());
  }
}

class AttendanceApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  AttendanceApiException(this.message, {this.statusCode, this.isNetworkError = false});

  @override
  String toString() => message;
}
