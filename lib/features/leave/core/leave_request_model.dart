class LeaveAttachment {
  final int id;
  final int leaveId;
  final String fileKey;
  final String fileType;
  final DateTime createdAt;
  final String fileUrl;

  LeaveAttachment({
    required this.id,
    required this.leaveId,
    required this.fileKey,
    required this.fileType,
    required this.createdAt,
    required this.fileUrl,
  });

  factory LeaveAttachment.fromJson(Map<String, dynamic> json) {
    return LeaveAttachment(
      id: json['id'] ?? 0,
      leaveId: json['leave_id'] ?? 0,
      fileKey: json['file_key'] ?? '',
      fileType: json['file_type'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      fileUrl: json['file_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leave_id': leaveId,
      'file_key': fileKey,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
      'file_url': fileUrl,
    };
  }
}

class LeaveRequest {
  final int id;
  final String? adminComment;
  final String leaveType;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime appliedAt;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final int orgId;
  final int userId;
  final num? payPercentage;
  final String? payType;
  final String? userName; // For admin view
  final String? userEmail; // For admin view
  final String? userPhone; // For admin view
  final String? userAvatar; // For avatar display
  final String? policyName;
  final String? leaveCode;
  final bool isActive;
  final bool isDeleted;
  final List<LeaveAttachment> attachments;

  LeaveRequest({
    required this.id,
    this.adminComment,
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.appliedAt,
    this.reviewedBy,
    this.reviewedAt,
    required this.orgId,
    required this.userId,
    this.payPercentage,
    this.payType,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAvatar,
    this.policyName,
    this.leaveCode,
    this.isActive = true,
    this.isDeleted = false,
    this.attachments = const [],
  });

  int get durationDays {
    final diff = endDate.difference(startDate).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    String cleanString(String? input) {
      if (input == null) return '';
      String cleaned = input.trim();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      cleaned = cleaned.replaceAll('\\"', '"');
      if (cleaned.endsWith(',')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      return cleaned.trim();
    }

    final idValue = json['id'] ?? json['lr_id'] ?? 0;
    final statusValue = cleanString(json['status'] ?? 'pending').toLowerCase();

    bool parseBool(dynamic val, bool defaultVal) {
      if (val == null) return defaultVal;
      if (val is bool) return val;
      if (val == 1 || val == '1' || val.toString().toLowerCase() == 'true') return true;
      if (val == 0 || val == '0' || val.toString().toLowerCase() == 'false') return false;
      return defaultVal;
    }

    return LeaveRequest(
      id: idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0,
      adminComment: json['admin_comment']?.toString() == "0" ? null : json['admin_comment']?.toString(), 
      leaveType: cleanString(json['leave_type']),
      reason: cleanString(json['reason']),
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      status: statusValue,
      appliedAt: DateTime.parse(json['applied_at'] ?? DateTime.now().toIso8601String()).toLocal(),
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']).toLocal() : null,
      orgId: json['org_id'] is int ? json['org_id'] : int.tryParse(json['org_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      payPercentage: json['pay_percentage'],
      payType: json['pay_type'],
      userName: json['user_name'],
      userEmail: json['email'],
      userPhone: json['phone_no'],
      userAvatar: json['profile_image_url'] ?? json['profile_image'] ?? json['profile_pic'] ?? json['avatar_url'],
      policyName: json['policy_name'],
      leaveCode: json['leave_code'],
      isActive: parseBool(json['is_active'], true),
      isDeleted: parseBool(json['is_deleted'], false),
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => LeaveAttachment.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lr_id': id,
      'admin_comment': adminComment,
      'leave_type': leaveType,
      'reason': reason,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'applied_at': appliedAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'org_id': orgId,
      'user_id': userId,
      'pay_percentage': payPercentage,
      'pay_type': payType,
      'user_name': userName,
      'email': userEmail,
      'phone_no': userPhone,
      'profile_image': userAvatar,
      'policy_name': policyName,
      'leave_code': leaveCode,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }

  LeaveRequest copyWith({
    int? id,
    String? adminComment,
    String? leaveType,
    String? reason,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? appliedAt,
    int? reviewedBy,
    DateTime? reviewedAt,
    int? orgId,
    int? userId,
    num? payPercentage,
    String? payType,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userAvatar,
    String? policyName,
    String? leaveCode,
    bool? isActive,
    bool? isDeleted,
    List<LeaveAttachment>? attachments,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      adminComment: adminComment ?? this.adminComment,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      orgId: orgId ?? this.orgId,
      userId: userId ?? this.userId,
      payPercentage: payPercentage ?? this.payPercentage,
      payType: payType ?? this.payType,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userAvatar: userAvatar ?? this.userAvatar,
      policyName: policyName ?? this.policyName,
      leaveCode: leaveCode ?? this.leaveCode,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      attachments: attachments ?? this.attachments,
    );
  }
}

// [mod:2026-02-20T09:15:00+05:30]

// [upd:2026-05-11T11:30:00+05:30]
