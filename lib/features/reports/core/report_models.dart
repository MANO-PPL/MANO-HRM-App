import 'package:flutter/material.dart';

class ReportSummaryStats {
  final int present;
  final int absent;
  final int leave;
  final int halfDay;
  final double overtimeHours;
  final int lateCount;

  const ReportSummaryStats({
    this.present = 0,
    this.absent = 0,
    this.leave = 0,
    this.halfDay = 0,
    this.overtimeHours = 0.0,
    this.lateCount = 0,
  });

  factory ReportSummaryStats.fromJson(Map<String, dynamic> json) {
    return ReportSummaryStats(
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      leave: (json['leave'] as num?)?.toInt() ?? 0,
      halfDay: (json['halfDay'] as num?)?.toInt() ?? 0,
      overtimeHours: (json['overtime'] as num?)?.toDouble() ?? 0.0,
      lateCount: (json['lateCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'present': present,
        'absent': absent,
        'leave': leave,
        'halfDay': halfDay,
        'overtime': overtimeHours,
        'lateCount': lateCount,
      };
}

class AttendanceMatrixDayRecord {
  final String date; // "YYYY-MM-DD"
  final String status; // "P", "A", "L", "HD", "WO", "H"
  final String? clockIn;
  final String? clockOut;
  final String? workDuration;
  final double overtimeHours;
  final String? inLocation;
  final String? outLocation;
  final String? verificationImage;
  final bool isLate;
  final int lateMinutes;
  final String? reason;

  const AttendanceMatrixDayRecord({
    required this.date,
    required this.status,
    this.clockIn,
    this.clockOut,
    this.workDuration,
    this.overtimeHours = 0.0,
    this.inLocation,
    this.outLocation,
    this.verificationImage,
    this.isLate = false,
    this.lateMinutes = 0,
    this.reason,
  });

  factory AttendanceMatrixDayRecord.fromJson(Map<String, dynamic> json) {
    final otVal = json['overtime'] ?? json['overtime_hours'] ?? json['overtimeHours'];
    final double ot = (otVal is num) ? otVal.toDouble() : (double.tryParse(otVal?.toString() ?? '') ?? 0.0);

    final lateVal = json['late_minutes'] ?? json['lateMinutes'] ?? json['late'];
    final int lateMins = (lateVal is num) ? lateVal.toInt() : (int.tryParse(lateVal?.toString() ?? '') ?? 0);

    return AttendanceMatrixDayRecord(
      date: (json['rawDate'] ?? json['date'] ?? '').toString(),
      status: (json['status'] ?? 'A').toString(),
      clockIn: json['clock_in'] ?? json['clockIn'] ?? json['time_in'],
      clockOut: json['clock_out'] ?? json['clockOut'] ?? json['time_out'],
      workDuration: (json['work_duration'] ?? json['workDuration'] ?? json['work_hrs'] ?? json['total_hrs'])?.toString(),
      overtimeHours: ot,
      inLocation: json['in_location'] ?? json['inLocation'] ?? json['time_in_address'],
      outLocation: json['out_location'] ?? json['outLocation'] ?? json['time_out_address'],
      verificationImage: json['verification_image'] ?? json['verificationImage'] ?? json['time_in_image'],
      isLate: json['is_late'] == true || (json['is_late']?.toString().toLowerCase() == 'true') || lateMins > 0,
      lateMinutes: lateMins,
      reason: json['reason'],
    );
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'P':
      case 'PRESENT':
        return const Color(0xFF10B981);
      case 'A':
      case 'ABSENT':
        return const Color(0xFFEF4444);
      case 'L':
      case 'LEAVE':
        return const Color(0xFF0284C7);
      case 'HD':
      case 'HALF_DAY':
        return const Color(0xFF6366F1);
      case 'WO':
      case 'WEEK_OFF':
        return const Color(0xFF64748B);
      case 'H':
      case 'HOLIDAY':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String get shortStatus {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return 'P';
      case 'ABSENT':
        return 'A';
      case 'LEAVE':
        return 'L';
      case 'HALF_DAY':
        return 'HD';
      case 'WEEK_OFF':
        return 'WO';
      case 'HOLIDAY':
        return 'H';
      default:
        return status;
    }
  }
}

class AttendanceMatrixEmployee {
  final String userId;
  final String name;
  final String employeeId;
  final String department;
  final String designation;
  final String? avatarUrl;
  final Map<String, AttendanceMatrixDayRecord> dailyRecords; // "YYYY-MM-DD" -> Record

  const AttendanceMatrixEmployee({
    required this.userId,
    required this.name,
    required this.employeeId,
    required this.department,
    required this.designation,
    this.avatarUrl,
    required this.dailyRecords,
  });

  factory AttendanceMatrixEmployee.fromJson(Map<String, dynamic> json) {
    final Map<String, AttendanceMatrixDayRecord> records = {};
    if (json['days'] is Map) {
      (json['days'] as Map).forEach((key, val) {
        records[key.toString()] = AttendanceMatrixDayRecord.fromJson(Map<String, dynamic>.from(val));
      });
    } else if (json['records'] is List) {
      for (final r in json['records']) {
        final rec = AttendanceMatrixDayRecord.fromJson(Map<String, dynamic>.from(r));
        records[rec.date] = rec;
      }
    }

    return AttendanceMatrixEmployee(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['user_name'] ?? json['name'] ?? 'Employee',
      employeeId: json['employee_id'] ?? json['emp_id'] ?? 'EMP-001',
      department: json['department'] ?? 'General',
      designation: json['designation'] ?? 'Staff',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      dailyRecords: records,
    );
  }
}

class ReportPreviewResult {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final ReportSummaryStats summary;
  final List<AttendanceMatrixEmployee> matrix;
  final List<String> matrixDates; // Sorted date strings for matrix headers

  const ReportPreviewResult({
    required this.columns,
    required this.rows,
    required this.summary,
    required this.matrix,
    required this.matrixDates,
  });
}

// [mod:2026-02-26T09:00:00+05:30]

// [upd:2026-05-10T09:00:00+05:30]
