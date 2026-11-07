import 'package:intl/intl.dart';

/// Matches the backend audit log schema:
/// { log_id, action, performed_by_name, employee_name, details, created_at }
class PayrollAuditLog {
  final String logId;
  final String action;
  final String performedByName;
  final String? employeeName;
  final String details;
  final DateTime createdAt;

  const PayrollAuditLog({
    required this.logId,
    required this.action,
    required this.performedByName,
    this.employeeName,
    required this.details,
    required this.createdAt,
  });

  factory PayrollAuditLog.fromJson(Map<String, dynamic> json) {
    return PayrollAuditLog(
      logId: json['log_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      performedByName: json['performed_by_name']?.toString() ?? '—',
      employeeName: json['employee_name']?.toString(),
      details: json['details']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Human-readable timestamp: "11 Aug 2026, 12:30 PM"
  String get formattedTime {
    return DateFormat('d MMMM yyyy, hh:mm a').format(createdAt.toLocal());
  }
}

// [mod:2026-02-25T09:00:00+05:30]

// [upd:2026-05-11T11:30:00+05:30]
