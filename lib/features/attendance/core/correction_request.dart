import 'dart:convert';

enum CorrectionType { missedDay, missedPunch, other, correction, overtime }
enum CorrectionMethod { addSession, fix, reset }
enum RequestStatus { pending, approved, rejected }

class AttendanceCorrectionRequest {
  final String id;
  final String userId;
  final String? employeeId;
  final String userName;
  final String? userAvatar;
  final DateTime requestDate;
  final CorrectionType type;
  final CorrectionMethod method;
  final String reason;
  final RequestStatus status;
  
  // Data for the correction
  final Map<String, dynamic>? correctionData;
  
  // Helper accessors for correctionData (Checks both nested and top-level for flexibility)
  List<Map<String, String>> get sessions {
    if (correctionData != null && correctionData!['sessions'] != null) {
      final rawList = correctionData!['sessions'];
      if (rawList is List) {
        return rawList.map<Map<String, String>>((x) {
          if (x is Map) {
            return {
              'time_in': x['time_in']?.toString() ?? x['in']?.toString() ?? '',
              'time_out': x['time_out']?.toString() ?? x['out']?.toString() ?? '',
              if (x['punch_type'] != null) 'punch_type': x['punch_type'].toString(),
              if (x['is_overnight'] != null) 'is_overnight': x['is_overnight'].toString(),
            };
          }
          return {'time_in': '', 'time_out': ''};
        }).toList();
      }
    }
    // Check top level (if backend returns it flat)
    return [];
  }
  
  String? get requestedTimeIn => correctionData?['time_in']?.toString() ?? correctionData?['requested_time_in']?.toString();
  String? get requestedTimeOut => correctionData?['time_out']?.toString() ?? correctionData?['requested_time_out']?.toString();
  
  // Aliases for UI compatibility
  String? get timeIn => requestedTimeIn;
  String? get timeOut => requestedTimeOut;

  final List<dynamic>? auditTrail;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewComments;

  final DateTime? submittedAt;
  final int? desgId;
  final String? designation;

  final String? attachmentUrl;
  final List<Map<String, String>>? originalSessions;
  final double? latitude;
  final double? longitude;

  AttendanceCorrectionRequest({
    required this.id,
    required this.userId,
    this.employeeId,
    required this.userName,
    this.userAvatar,
    required this.requestDate,
    required this.type,
    required this.method,
    required this.reason,
    this.status = RequestStatus.pending,
    this.correctionData,
    this.auditTrail,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComments,
    this.submittedAt,
    this.desgId,
    this.designation,
    this.attachmentUrl,
    this.originalSessions,
    this.latitude,
    this.longitude,
  });

  factory AttendanceCorrectionRequest.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['request_date'] != null 
          ? DateTime.parse(json['request_date']) 
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final Map<String, dynamic> cData = json['correction_data'] is Map 
        ? Map<String, dynamic>.from(json['correction_data']) 
        : {};

    // 1. Parse proposed_data (Backend attn_corrections column)
    dynamic proposed = json['proposed_data'];
    if (proposed is String) {
      try {
        proposed = jsonDecode(proposed);
      } catch (_) {}
    }

    String? foundAttachmentUrl = json['attachment_url']?.toString() ?? json['attachment']?['file_url']?.toString();

    if (proposed is List && proposed.isNotEmpty) {
      final validSessions = <Map<String, dynamic>>[];
      for (final item in proposed) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          validSessions.add(itemMap);
          if (foundAttachmentUrl == null && itemMap['attachment'] is Map) {
            foundAttachmentUrl = itemMap['attachment']['file_url']?.toString() ?? itemMap['attachment']['url']?.toString();
          }
        }
      }
      if (validSessions.isNotEmpty) {
        cData['sessions'] = validSessions;
        final first = validSessions.first;
        if (first['time_in'] != null && first['time_in'].toString().isNotEmpty) {
          cData['requested_time_in'] = first['time_in'].toString();
        }
        final last = validSessions.last;
        if (last['time_out'] != null && last['time_out'].toString().isNotEmpty) {
          cData['requested_time_out'] = last['time_out'].toString();
        }
      }
    } else if (proposed is Map) {
      if (proposed['sessions'] != null && proposed['sessions'] is List) {
        cData['sessions'] = proposed['sessions'];
      }
      if (proposed['time_in'] != null) cData['requested_time_in'] = proposed['time_in'].toString();
      if (proposed['time_out'] != null) cData['requested_time_out'] = proposed['time_out'].toString();
      if (foundAttachmentUrl == null && proposed['attachment'] is Map) {
        foundAttachmentUrl = proposed['attachment']['file_url']?.toString() ?? proposed['attachment']['url']?.toString();
      }
    }

    // 2. Parse original_data
    List<Map<String, String>>? parsedOriginal;
    dynamic orig = json['original_data'];
    if (orig is String) {
      try {
        orig = jsonDecode(orig);
      } catch (_) {}
    }
    if (orig is List) {
      parsedOriginal = orig.map<Map<String, String>>((item) {
        if (item is Map) {
          return {
            'time_in': item['time_in']?.toString() ?? '',
            'time_out': item['time_out']?.toString() ?? '',
          };
        }
        return {'time_in': '', 'time_out': ''};
      }).toList();
    }

    if (json['requested_time_in'] != null) cData['requested_time_in'] = json['requested_time_in'];
    if (json['requested_time_out'] != null) cData['requested_time_out'] = json['requested_time_out'];
    if (json['sessions'] != null) cData['sessions'] = json['sessions'];

    return AttendanceCorrectionRequest(
      id: json['acr_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['emp_id']?.toString() ?? json['emp_code']?.toString() ?? json['employee_code']?.toString() ?? json['user_code']?.toString(),
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['profile_image']?.toString() ?? json['profile_image_url']?.toString() ?? json['profile_pic']?.toString() ?? json['avatar_url']?.toString(),
      requestDate: parsedDate,
      type: _parseType(json['correction_type']?.toString()),
      method: _parseMethod(json['correction_method']?.toString()),
      reason: json['acr_reason']?.toString() ?? json['reason']?.toString() ?? json['remarks']?.toString() ?? json['description']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      correctionData: cData.isNotEmpty ? cData : null,
      auditTrail: json['audit_trail'] is List ? List<dynamic>.from(json['audit_trail']) : null,
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      reviewComments: json['review_comments']?.toString(),
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
      desgId: json['desg_id'] is int ? json['desg_id'] : int.tryParse(json['desg_id']?.toString() ?? ''),
      designation: json['designation']?.toString(),
      attachmentUrl: foundAttachmentUrl,
      originalSessions: parsedOriginal,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (employeeId != null) 'employee_id': employeeId,
      'request_date': requestDate.toIso8601String().split('T')[0],
      'correction_type': type.toString().split('.').last.replaceAll(RegExp(r'(?=[A-Z])'), '_').toLowerCase(),
      'correction_method': method.toString().split('.').last.replaceAll(RegExp(r'(?=[A-Z])'), '_').toLowerCase(),
      'reason': reason,
      'status': status.toString().split('.').last,
      if (correctionData != null) ...correctionData!,
      'review_comments': reviewComments,
    };
  }

  static CorrectionType _parseType(String? val) {
    if (val == null) return CorrectionType.other;
    final normalized = val.toLowerCase().replaceAll('_', '');
    if (normalized.contains('missedday') || normalized.contains('day')) return CorrectionType.missedDay;
    if (normalized.contains('missed')) return CorrectionType.missedPunch;
    if (normalized.contains('correction')) return CorrectionType.missedDay;
    if (normalized.contains('overtime')) return CorrectionType.other;
    if (normalized.contains('incorrect')) return CorrectionType.missedPunch;
    if (normalized.contains('regular')) return CorrectionType.missedDay;
    return CorrectionType.other;
  }

  static CorrectionMethod _parseMethod(String? val) {
    if (val == null) return CorrectionMethod.addSession;
    final normalized = val.toLowerCase().replaceAll('_', '');
    if (normalized.contains('reset')) return CorrectionMethod.reset;
    if (normalized.contains('fix')) return CorrectionMethod.fix;
    return CorrectionMethod.addSession;
  }

  static RequestStatus _parseStatus(String? val) {
    if (val == null) return RequestStatus.pending;
    return RequestStatus.values.firstWhere(
      (e) => e.toString().split('.').last == val.toLowerCase(), 
      orElse: () => RequestStatus.pending
    );
  }

  String get typeLabel {
    switch (type) {
      case CorrectionType.missedDay: return 'Missed Day';
      case CorrectionType.missedPunch: return 'Missed Punch';
      case CorrectionType.other: return 'Other Reason';
      case CorrectionType.correction: return 'Missed Day';
      case CorrectionType.overtime: return 'Other Reason';
    }
  }

  String get methodLabel {
    switch (method) {
      case CorrectionMethod.addSession: return 'Add Session';
      case CorrectionMethod.fix: return 'Fix Timings';
      case CorrectionMethod.reset: return 'Reset Day';
    }
  }
}


// [mod:2026-02-17T11:30:00+05:30]

// [upd:2026-05-11T09:00:00+05:30]
