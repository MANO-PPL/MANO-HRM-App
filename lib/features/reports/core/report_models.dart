import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportSummaryStats {
  final int present;
  final int absent;
  final int leave;
  final int halfDay;
  final double overtimeHours;
  final int lateCount;
  final int missedPunch;

  const ReportSummaryStats({
    this.present = 0,
    this.absent = 0,
    this.leave = 0,
    this.halfDay = 0,
    this.overtimeHours = 0.0,
    this.lateCount = 0,
    this.missedPunch = 0,
  });

  factory ReportSummaryStats.fromJson(Map<String, dynamic> json) {
    return ReportSummaryStats(
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      leave: (json['leave'] as num?)?.toInt() ?? 0,
      halfDay: (json['halfDay'] as num?)?.toInt() ?? 0,
      overtimeHours: (json['overtime'] as num?)?.toDouble() ?? 0.0,
      lateCount: (json['lateCount'] as num?)?.toInt() ?? 0,
      missedPunch: (json['missedPunch'] ?? json['missed_punch'] ?? json['missed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'present': present,
        'absent': absent,
        'leave': leave,
        'halfDay': halfDay,
        'overtime': overtimeHours,
        'lateCount': lateCount,
        'missedPunch': missedPunch,
      };
}

class AttendanceMatrixDayRecord {
  final String date; // "YYYY-MM-DD"
  final String status; // "P", "A", "L", "HD", "WO", "H", "MP", "OT"
  final String? clockIn;
  final String? clockOut;
  final String? workDuration;
  final double overtimeHours;
  final String? inLocation;
  final String? outLocation;
  final String? verificationImage;
  final String? timeInImage;
  final String? timeOutImage;
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
    this.timeInImage,
    this.timeOutImage,
    this.isLate = false,
    this.lateMinutes = 0,
    this.reason,
  });

  factory AttendanceMatrixDayRecord.fromJson(Map<String, dynamic> json) {
    final otVal = json['overtime'] ?? json['overtime_hours'] ?? json['overtimeHours'];
    final double ot = (otVal is num) ? otVal.toDouble() : (double.tryParse(otVal?.toString() ?? '') ?? 0.0);

    final lateVal = json['late_minutes'] ?? json['lateMinutes'] ?? json['late'];
    final int lateMins = (lateVal is num) ? lateVal.toInt() : (int.tryParse(lateVal?.toString() ?? '') ?? 0);

    var rawStatus = (json['status'] ?? 'A').toString();
    if (rawStatus.toLowerCase().contains('late') && rawStatus.toLowerCase().contains('overtime')) {
      rawStatus = 'Overtime';
    }

    final inImg = json['time_in_image'] ?? json['timeInImage'] ?? json['verification_image'] ?? json['verificationImage'];
    final outImg = json['time_out_image'] ?? json['timeOutImage'];

    return AttendanceMatrixDayRecord(
      date: (json['rawDate'] ?? json['date'] ?? '').toString(),
      status: rawStatus,
      clockIn: json['clock_in'] ?? json['clockIn'] ?? json['time_in'],
      clockOut: json['clock_out'] ?? json['clockOut'] ?? json['time_out'],
      workDuration: (json['work_duration'] ?? json['workDuration'] ?? json['work_hrs'] ?? json['total_hrs'])?.toString(),
      overtimeHours: ot,
      inLocation: json['in_location'] ?? json['inLocation'] ?? json['time_in_address'],
      outLocation: json['out_location'] ?? json['outLocation'] ?? json['time_out_address'],
      verificationImage: inImg,
      timeInImage: inImg,
      timeOutImage: outImg,
      isLate: json['is_late'] == true || (json['is_late']?.toString().toLowerCase() == 'true') || lateMins > 0,
      lateMinutes: lateMins,
      reason: json['reason'],
    );
  }

  Color get statusColor {
    final s = status.toUpperCase().trim();
    if (s.isEmpty || s == '-' || s.contains('NOT RECORDED') || s == 'UNRECORDED') {
      return Colors.grey;
    }
    if (s == 'P' || s == 'PRESENT' || s.contains('PRESENT')) {
      return const Color(0xFF10B981);
    }
    if (s == 'MP' || s.contains('MISSED') || s == 'MISSED_PUNCH') {
      return const Color(0xFFF59E0B);
    }
    if (s == 'A' || s == 'ABSENT') {
      return const Color(0xFFEF4444);
    }
    if (s == 'OT' || s.contains('OVERTIME')) {
      return const Color(0xFF8B5CF6);
    }
    if (s == 'L' || s == 'LEAVE' || s == 'ON LEAVE') {
      return const Color(0xFF0284C7);
    }
    if (s == 'HD' || s == 'HALF_DAY' || s == 'HALF DAY') {
      return const Color(0xFF6366F1);
    }
    if (s == 'H' || s == 'HOLIDAY') {
      return const Color(0xFF0284C7);
    }
    if (s == 'WO' || s == 'WEEK_OFF' || s == 'WEEK OFF' || s == 'SUN' || s == 'SAT') {
      return const Color(0xFF64748B);
    }
    return Colors.grey;
  }

  String get shortStatus {
    final s = status.toUpperCase().trim();
    if (s.isEmpty || s == '-' || s.contains('NOT RECORDED') || s == 'UNRECORDED' || s == '·') return '-';
    if (s == 'PRESENT' || s == 'P') return 'P';
    if (s == 'ABSENT' || s == 'A') return 'A';
    if (s.contains('MISSED') || s == 'MP') return 'MP';
    if (s.contains('OVERTIME') || s == 'OT') return 'OT';
    if (s == 'LEAVE' || s == 'ON LEAVE' || s == 'L') return 'L';
    if (s == 'HALF_DAY' || s == 'HALF DAY' || s == 'HD') return 'HD';
    if (s == 'WEEK_OFF' || s == 'WEEK OFF' || s == 'WO' || s == 'SUN' || s == 'SAT') return 'WO';
    if (s == 'HOLIDAY' || s == 'H') return 'H';
    if (s.length > 2) return s.substring(0, 2);
    return status;
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

  int get presentCount => dailyRecords.values.where((r) => r.status == 'P' || r.status == 'PRESENT').length;
  int get absentCount => dailyRecords.values.where((r) => r.status == 'A' || r.status == 'ABSENT').length;
  int get leaveCount => dailyRecords.values.where((r) => r.status == 'L' || r.status == 'LEAVE').length;
  int get halfDayCount => dailyRecords.values.where((r) => r.status == 'HD' || r.status == 'HALF_DAY').length;
  int get lateCount => dailyRecords.values.where((r) => r.isLate).length;
  int get missedPunchCount => dailyRecords.values.where((r) => r.status == 'MP' || r.status.contains('MISSED')).length;
  int get weeklyOffCount => dailyRecords.values.where((r) => r.status == 'WO').length;
  int get holidayCount => dailyRecords.values.where((r) => r.status == 'H').length;
  double get overtimeHours => dailyRecords.values.fold(0.0, (acc, r) => acc + r.overtimeHours);
}

class MusterRollDateHeader {
  final String dateStr;
  final String dayOfWeek;
  final String dayNum;
  final String dateFormatted;
  final bool isSunday;
  final bool isHoliday;
  final String holidayName;
  final bool isHighlight;

  const MusterRollDateHeader({
    required this.dateStr,
    required this.dayOfWeek,
    required this.dayNum,
    required this.dateFormatted,
    this.isSunday = false,
    this.isHoliday = false,
    this.holidayName = '',
    this.isHighlight = false,
  });

  factory MusterRollDateHeader.fromJson(Map<String, dynamic> json) {
    return MusterRollDateHeader(
      dateStr: json['dateStr']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      dayNum: json['dayNum']?.toString() ?? '',
      dateFormatted: json['dateFormatted']?.toString() ?? '',
      isSunday: json['isSunday'] == true,
      isHoliday: json['isHoliday'] == true,
      holidayName: json['holidayName']?.toString() ?? '',
      isHighlight: json['isHighlight'] == true || json['isSunday'] == true || json['isHoliday'] == true,
    );
  }
}

class MusterRollEmployee {
  final int srNo;
  final String userId;
  final String name;
  final String position;
  final String employeeCode;
  final String grade;
  final int daysInMonth;
  final String presentDays;
  final List<String> statusRow;
  final List<String> workHourRow;
  final List<String> inRow;
  final List<String> outRow;

  const MusterRollEmployee({
    required this.srNo,
    required this.userId,
    required this.name,
    required this.position,
    required this.employeeCode,
    this.grade = '-',
    required this.daysInMonth,
    required this.presentDays,
    required this.statusRow,
    required this.workHourRow,
    required this.inRow,
    required this.outRow,
  });

  factory MusterRollEmployee.fromJson(Map<String, dynamic> json) {
    List<String> toStrList(dynamic list) {
      if (list is List) {
        return list.map((e) => e?.toString() ?? '').toList();
      }
      return [];
    }

    return MusterRollEmployee(
      srNo: (json['srNo'] as num?)?.toInt() ?? 1,
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Employee',
      position: json['position']?.toString() ?? '-',
      employeeCode: json['employeeCode']?.toString() ?? '-',
      grade: json['grade']?.toString() ?? '-',
      daysInMonth: (json['daysInMonth'] as num?)?.toInt() ?? 0,
      presentDays: json['presentDays']?.toString() ?? '0',
      statusRow: toStrList(json['statusRow']),
      workHourRow: toStrList(json['workHourRow']),
      inRow: toStrList(json['inRow']),
      outRow: toStrList(json['outRow']),
    );
  }
}

class MusterRollData {
  final String monthTitle;
  final String companyName;
  final int daysInMonth;
  final List<MusterRollDateHeader> dateHeaders;
  final List<MusterRollEmployee> employees;
  final Map<String, dynamic> columnsConfig;

  const MusterRollData({
    required this.monthTitle,
    required this.companyName,
    required this.daysInMonth,
    required this.dateHeaders,
    required this.employees,
    this.columnsConfig = const {},
  });

  factory MusterRollData.fromJson(Map<String, dynamic> json) {
    final List<MusterRollDateHeader> headers = [];
    if (json['dateHeaders'] is List) {
      for (final h in json['dateHeaders']) {
        if (h is Map) {
          headers.add(MusterRollDateHeader.fromJson(Map<String, dynamic>.from(h)));
        }
      }
    }

    final List<MusterRollEmployee> emps = [];
    if (json['employees'] is List) {
      for (final e in json['employees']) {
        if (e is Map) {
          emps.add(MusterRollEmployee.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    return MusterRollData(
      monthTitle: json['monthTitle']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      daysInMonth: (json['daysInMonth'] as num?)?.toInt() ?? headers.length,
      dateHeaders: headers,
      employees: emps,
      columnsConfig: json['columnsConfig'] is Map ? Map<String, dynamic>.from(json['columnsConfig']) : {},
    );
  }
}

class ReportPreviewResult {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final ReportSummaryStats summary;
  final List<AttendanceMatrixEmployee> matrix;
  final List<String> matrixDates; // Sorted date strings for matrix headers
  final MusterRollData? musterRoll;

  const ReportPreviewResult({
    required this.columns,
    required this.rows,
    required this.summary,
    required this.matrix,
    required this.matrixDates,
    this.musterRoll,
  });
}

class ReportWeekOption {
  final String label; // "Week 1 (01 Nov - 07 Nov)"
  final String value; // "2026-11-01"
  final DateTime start;
  final DateTime end;
  final int weekNumber;

  const ReportWeekOption({
    required this.label,
    required this.value,
    required this.start,
    required this.end,
    required this.weekNumber,
  });

  static List<ReportWeekOption> getWeeksOfMonth(DateTime monthDate) {
    final year = monthDate.year;
    final monthNum = monthDate.month;
    final lastDay = DateUtils.getDaysInMonth(year, monthNum);
    final firstDate = DateTime(year, monthNum, 1);
    final lastDate = DateTime(year, monthNum, lastDay);

    final List<ReportWeekOption> weeks = [];
    DateTime currentStart = firstDate;
    while (!currentStart.isAfter(lastDate)) {
      final dayOfWeek = currentStart.weekday; // 1 = Mon, 7 = Sun
      final daysToSunday = (dayOfWeek == DateTime.sunday) ? 0 : (7 - dayOfWeek);
      DateTime currentEnd = currentStart.add(Duration(days: daysToSunday));
      if (currentEnd.isAfter(lastDate)) {
        currentEnd = lastDate;
      }
      final weekNum = weeks.length + 1;
      final label = "Week $weekNum (${DateFormat('dd MMM').format(currentStart)} - ${DateFormat('dd MMM').format(currentEnd)})";
      final valStr = DateFormat('yyyy-MM-dd').format(currentStart);
      weeks.add(ReportWeekOption(
        label: label,
        value: valStr,
        start: currentStart,
        end: currentEnd,
        weekNumber: weekNum,
      ));

      currentStart = currentEnd.add(const Duration(days: 1));
    }
    return weeks;
  }
}

// [mod:2026-02-26T09:00:00+05:30]

// [upd:2026-05-10T09:00:00+05:30]
