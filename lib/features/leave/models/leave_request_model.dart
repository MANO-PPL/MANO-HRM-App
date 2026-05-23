import 'package:flutter/foundation.dart';

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
    this.attachments = const [],
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    String cleanString(String? input) {
      if (input == null) return '';
      // Remove starting/ending quotes and spaces if strictly wrapped like " \"Value\" "
      // The user example was: " \"Sick Leave\"," -> We need to be careful.
      // Looking at the example: " \"Sick Leave\"," might be a parsing artifact or actual data.
      // Let's trim outer spaces, then check for quotes.
      String cleaned = input.trim();
      
      // If it looks like a JSON string representation inside a string field, unquote it.
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
       // Handle escaped quotes inside
      cleaned = cleaned.replaceAll('\\"', '"');
      
      // Remove trailing comma if present (from the weird user output example)
      if (cleaned.endsWith(',')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      return cleaned.trim();
    }

    // Add logging for raw JSON in model
    debugPrint('LeaveRequest.fromJson: Raw JSON: $json');

    final idValue = json['id'] ?? json['lr_id'] ?? 0;
    final lrIdValue = json['lr_id'] ?? json['id'] ?? 0;
    final statusValue = cleanString(json['status'] ?? 'pending').toLowerCase();
    
    // Diagnostic logging - more descriptive
    debugPrint('LeaveRequest: Map -> ID=$idValue, LR_ID=$lrIdValue, Status=$statusValue');
    if (idValue == 17 || lrIdValue == 17) {
      debugPrint('PROTECTED LOG [ID 17]: ${json.toString()}');
    }

    return LeaveRequest(
      id: idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0,
      adminComment: json['admin_comment']?.toString() == "0" ? null : json['admin_comment'], 
      leaveType: cleanString(json['leave_type']),
      reason: cleanString(json['reason']),
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()).toLocal(),
      status: statusValue,
      appliedAt: DateTime.parse(json['applied_at'] ?? DateTime.now().toIso8601String()).toLocal(),
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at']).toLocal() : null,
      orgId: json['org_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      payPercentage: json['pay_percentage'],
      payType: json['pay_type'],
      userName: json['user_name'],
      userEmail: json['email'],
      userPhone: json['phone_no'],
      userAvatar: json['profile_image'] ?? json['profile_pic'] ?? json['avatar_url'],
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
      attachments: attachments ?? this.attachments,
    );
  }
}
