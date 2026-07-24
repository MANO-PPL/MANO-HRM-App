import '../../../shared/constants/api_constants.dart';

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
  final String? lateReason;
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
    this.lateReason,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: json['attendance_id'] ?? 0,
      userId: json['user_id'],
      timeIn: _parseDate(json['time_in']),
      timeOut: _parseDate(json['time_out']),
      timeInLat: _toDouble(json['time_in_lat']),
      timeInLng: _toDouble(json['time_in_lng']),
      timeOutLat: _toDouble(json['time_out_lat']),
      timeOutLng: _toDouble(json['time_out_lng']),
      timeInAddress: json['time_in_address'],
      timeOutAddress: json['time_out_address'],
      timeInImage: _parseImageUrl(
        json['time_in_image'] ?? 
        json['time_in_image_url'] ?? 
        json['timeInImage'] ?? 
        json['time_in_photo'] ?? 
        json['time_in_image_key']
      ), 
      timeOutImage: _parseImageUrl(
        json['time_out_image'] ?? 
        json['time_out_image_url'] ?? 
        json['timeOutImage'] ?? 
        json['time_out_photo'] ?? 
        json['time_out_image_key']
      ),
      lateMinutes: json['late_minutes'] ?? 0,
      lateReason: json['late_reason'],
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
    final cleanPath = str.startsWith('/') ? str : '/$str';
    String base = ApiConstants.baseUrl;
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return '$base$cleanPath';
  }
  
  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    return (val is num) ? val.toDouble() : double.tryParse(val.toString());
  }

  static String? _parseDate(dynamic val) {
    if (val == null) return null;
    // If it's already ISO (common case), DateTime.parse works
    try {
      // Try standard parse first
      return DateTime.parse(val.toString()).toIso8601String();
    } catch (_) {
      // Handle JS Date string: "Thu Jan 08 2026 11:48:36 GMT+0000 (Coordinated Universal Time)"
      try {
        final str = val.toString();
        // Extract the part we can parse: "Jan 08 2026 11:48:36" (Skip Day Name)
        // RegEx to grab "Mon Jan 08 2026 11:48:36" part or similar?
        // Let's simplified approach: Split by space.
        // Parts: Thu, Jan, 08, 2026, 11:48:36, GMT+0000, ...
        // We can construct a parseable string manually or use DateFormat.
        // NOTE: DateFormat requires specific locale sometimes.
        
        // Simpler: Just return the string as is? 
        // NO, the UI uses DateTime.parse(record.timeIn!). 
        // So we MUST return a valid ISO string here or null.
        
        // Let's try to parse "Jan 08 2026 11:48:36"
        // Thu Jan 08 2026 11:48:36 ...
        // 0   1   2  3    4
        final parts = str.split(' ');
        if (parts.length >= 5) {
           // parts[1] = Jan, parts[2] = 08, parts[3] = 2026, parts[4] = 11:48:36
           final monthStr = parts[1];
           final day = parts[2];
           final year = parts[3];
           final time = parts[4];
           
           final months = {
             'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04', 'May': '05', 'Jun': '06',
             'Jul': '07', 'Aug': '08', 'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
           };
           final month = months[monthStr] ?? '01';
           
           // ISO: YYYY-MM-DDTHH:mm:ss
           return "$year-$month-${day.padLeft(2, '0')}T$time";
        }
        return null; // Fail safe
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
      'late_reason': lateReason,
      'status': status,
    };
  }
}
