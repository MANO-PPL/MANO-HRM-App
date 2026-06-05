
enum CorrectionType { correction, missedPunch, overtime, other }
enum CorrectionMethod { addSession, fix, reset }
enum RequestStatus { pending, approved, rejected }

class AttendanceCorrectionRequest {
  final String id;
  final String userId;
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
      return List<Map<String, String>>.from(
        (correctionData!['sessions'] as List).map((x) => Map<String, String>.from(x))
      );
    }
    // Check top level (if backend returns it flat)
    return [];
  }
  
  String? get requestedTimeIn => correctionData?['time_in'] ?? correctionData?['requested_time_in'];
  String? get requestedTimeOut => correctionData?['time_out'] ?? correctionData?['requested_time_out'];
  
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

  final double? latitude;
  final double? longitude;

  AttendanceCorrectionRequest({
    required this.id,
    required this.userId,
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
    
    if (json['requested_time_in'] != null) cData['requested_time_in'] = json['requested_time_in'];
    if (json['requested_time_out'] != null) cData['requested_time_out'] = json['requested_time_out'];
    if (json['sessions'] != null) cData['sessions'] = json['sessions'];

    return AttendanceCorrectionRequest(
      id: json['acr_id']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
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
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
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
    if (normalized.contains('correction')) return CorrectionType.correction;
    if (normalized.contains('missed')) return CorrectionType.missedPunch;
    if (normalized.contains('overtime')) return CorrectionType.overtime;
    if (normalized.contains('incorrect')) return CorrectionType.correction; // Map legacy to Correction
    if (normalized.contains('regular')) return CorrectionType.correction; // Map legacy to Correction
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
      case CorrectionType.correction: return 'Correction';
      case CorrectionType.missedPunch: return 'Missed Punch';
      case CorrectionType.overtime: return 'Overtime';
      default: return 'Other';
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

