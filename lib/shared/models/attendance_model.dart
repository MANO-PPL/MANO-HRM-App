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
      timeInImage: json['time_in_image'], 
      timeOutImage: json['time_out_image'],
      lateMinutes: json['late_minutes'] ?? 0,
      status: json['status'] ?? 'Draft',
    );
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
