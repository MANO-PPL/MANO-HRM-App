import 'package:flutter_application/shared/constants/api_constants.dart';

class AttendanceRecord {
  final int attendanceId;
  final int? userId; // Link to user
  final String? timeIn; // ISO String
  final String? timeOut; // ISO String
  final double? timeInLat;
  final double? timeInLng;
  final double? timeOutLat;
  final double? timeOutLng;
  final String? timeInAddress;
  final String? timeOutAddress;
  final String? timeInImage; // URL
  final String? timeOutImage; // URL
  final int lateMinutes;
  final String status; // 'PRESENT', 'ABSENT', etc.

  AttendanceRecord({
    required this.attendanceId,
    this.userId,
    this.timeIn,
    this.timeOut,
    this.timeInLat,
    this.timeInLng,
    this.timeOutLat,
    this.timeOutLng,
    this.timeInAddress,
    this.timeOutAddress,
    this.timeInImage,
    this.timeOutImage,
    this.lateMinutes = 0,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: json['attendance_id'] ?? json['attendanceId'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? json['userId'],
      timeIn: _parseDate(json['time_in'] ?? json['timeIn'] ?? json['clock_in'] ?? json['clockIn'] ?? json['in']),
      timeOut: _parseDate(json['time_out'] ?? json['timeOut'] ?? json['clock_out'] ?? json['clockOut'] ?? json['out']),
      timeInLat: _toDouble(json['time_in_lat'] ?? json['timeInLat'] ?? json['latitude']),
      timeInLng: _toDouble(json['time_in_lng'] ?? json['timeInLng'] ?? json['longitude']),
      timeOutLat: _toDouble(json['time_out_lat'] ?? json['timeOutLat']),
      timeOutLng: _toDouble(json['time_out_lng'] ?? json['timeOutLng']),
      timeInAddress: json['time_in_address'] ?? json['timeInAddress'] ?? json['location'],
      timeOutAddress: json['time_out_address'] ?? json['timeOutAddress'],
      timeInImage: _parseImageUrl(
        json['time_in_image'] ?? 
        json['time_in_image_url'] ?? 
        json['timeInImage'] ?? 
        json['time_in_photo'] ?? 
        json['time_in_image_key'] ??
        json['image_url'] ??
        json['verification_image']
      ), 
      timeOutImage: _parseImageUrl(
        json['time_out_image'] ?? 
        json['time_out_image_url'] ?? 
        json['timeOutImage'] ?? 
        json['time_out_photo'] ?? 
        json['time_out_image_key']
      ),
      lateMinutes: json['late_minutes'] ?? json['lateMinutes'] ?? 0,
      status: json['status'] ?? 'Draft',
    );
  }

  static String? _parseImageUrl(dynamic rawUrl) {
    if (rawUrl == null) return null;
    final str = rawUrl.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:')) {
      return str;
    }
    final cleanKey = str.startsWith('/') ? str.substring(1) : str;
    String base = ApiConstants.baseUrl;
    if (base.endsWith('/api')) {
      return '$base/attendance/image?key=${Uri.encodeComponent(cleanKey)}';
    }
    return '$base/api/attendance/image?key=${Uri.encodeComponent(cleanKey)}';
  }
  
  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    return (val is num) ? val.toDouble() : double.tryParse(val.toString());
  }

  static String? _parseDate(dynamic val) {
    if (val == null) return null;
    try {
      // Try standard parse first
      return DateTime.parse(val.toString()).toIso8601String();
    } catch (_) {
      // Handle JS Date string: "Thu Jan 08 2026 11:48:36 GMT+0000 (Coordinated Universal Time)"
      try {
        final str = val.toString();
        // Thu Jan 08 2026 11:48:36 ...
        // 0   1   2  3    4
        final parts = str.split(' ');
        if (parts.length >= 5) {
           final monthStr = parts[1];
           final day = parts[2];
           final year = parts[3];
           final time = parts[4];
           
           final months = {
             'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
             'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
           };
           final month = months[monthStr] ?? '01';
           
           return "$year-$month-${day.padLeft(2, '0')}T$time";
        }
        return null;
      } catch (e) {
        return null;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance_id': attendanceId,
      'user_id': userId,
      'time_in': timeIn,
      'time_out': timeOut,
      'time_in_lat': timeInLat,
      'time_in_lng': timeInLng,
      'time_out_lat': timeOutLat,
      'time_out_lng': timeOutLng,
      'time_in_address': timeInAddress,
      'time_out_address': timeOutAddress,
      'time_in_image': timeInImage,
      'time_out_image': timeOutImage,
      'late_minutes': lateMinutes,
      'status': status,
    };
  }
}
