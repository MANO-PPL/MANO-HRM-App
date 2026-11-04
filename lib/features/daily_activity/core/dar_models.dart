import 'dart:convert';

enum DarItemType { task, meeting, event }

class DarActivity {
  final int? activityId;
  final String title;
  final String description;
  final String startTime; // HH:MM
  final String endTime;   // HH:MM
  final String activityDate; // YYYY-MM-DD
  final String activityType; // Category e.g. GENERAL (uppercase)
  final String status;       // PLANNED, COMPLETED

  DarActivity({
    this.activityId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.activityDate,
    required this.activityType,
    required this.status,
  });

  factory DarActivity.fromJson(Map<String, dynamic> json) {
    String rawStart = json['start_time'] ?? '';
    String rawEnd = json['end_time'] ?? '';
    return DarActivity(
      activityId: json['activity_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: rawStart.length >= 5 ? rawStart.substring(0, 5) : rawStart,
      endTime: rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd,
      activityDate: json['activity_date'] ?? '',
      activityType: json['activity_type'] ?? 'GENERAL',
      status: json['status'] ?? 'COMPLETED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (activityId != null) 'activity_id': activityId,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'activity_date': activityDate,
      'activity_type': activityType.toUpperCase(),
      'status': status,
    };
  }
}

class DarEvent {
  final int? eventId;
  final String title;
  final String description;
  final String startTime; // HH:MM
  final String endTime;   // HH:MM
  final String eventDate; // YYYY-MM-DD
  final String type;      // MEETING or EVENT
  final String location;  // meeting link or location address

  DarEvent({
    this.eventId,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.eventDate,
    required this.type,
    required this.location,
  });

  factory DarEvent.fromJson(Map<String, dynamic> json) {
    String rawStart = json['start_time'] ?? '';
    String rawEnd = json['end_time'] ?? '';
    return DarEvent(
      eventId: json['event_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: rawStart.length >= 5 ? rawStart.substring(0, 5) : rawStart,
      endTime: rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd,
      eventDate: json['event_date'] ?? '',
      type: json['type'] ?? 'MEETING',
      location: json['location'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (eventId != null) 'event_id': eventId,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'event_date': eventDate,
      'type': type.toUpperCase(),
      'location': location,
    };
  }
}

class DarItem {
  final String id; // format: act-ID or evt-ID or draft-timestamp
  final String title;
  final String description;
  final String startTime; // HH:MM
  final String endTime;   // HH:MM
  final String date;      // YYYY-MM-DD
  final DarItemType type;
  final String category;  // For tasks (e.g. General, Dev)
  final String status;    // For tasks (e.g. PLANNED, COMPLETED)
  final String location;  // For events (meet link or physical location)
  final bool isSaved;
  
  // Stacking parameters for MultiDayTimeline rendering layout calculations
  int laneIndex;
  int totalLanes;

  DarItem({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.type,
    this.category = 'General',
    this.status = 'COMPLETED',
    this.location = '',
    this.isSaved = true,
    this.laneIndex = 0,
    this.totalLanes = 1,
  });

  bool get isOnline {
    final loc = location.toLowerCase();
    return loc.startsWith('http://') || loc.startsWith('https://');
  }

  factory DarItem.fromActivity(DarActivity act) {
    return DarItem(
      id: 'act-${act.activityId}',
      title: act.title,
      description: act.description,
      startTime: act.startTime,
      endTime: act.endTime,
      date: act.activityDate,
      type: DarItemType.task,
      category: act.activityType,
      status: act.status,
      isSaved: true,
    );
  }

  factory DarItem.fromEvent(DarEvent evt) {
    return DarItem(
      id: 'evt-${evt.eventId}',
      title: evt.title,
      description: evt.description,
      startTime: evt.startTime,
      endTime: evt.endTime,
      date: evt.eventDate,
      type: evt.type.toUpperCase() == 'EVENT' ? DarItemType.event : DarItemType.meeting,
      location: evt.location,
      isSaved: true,
    );
  }

  DarItem copyWith({
    String? id,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    String? date,
    DarItemType? type,
    String? category,
    String? status,
    String? location,
    bool? isSaved,
  }) {
    return DarItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      status: status ?? this.status,
      location: location ?? this.location,
      isSaved: isSaved ?? this.isSaved,
      laneIndex: laneIndex,
      totalLanes: totalLanes,
    );
  }
}

class DarRequestItem {
  final int requestId;
  final int userId;
  final String userName;
  final String? userEmail;
  final String? userRole;
  final String? userDept;
  final String requestDate;
  final String reason;
  final String status; // PENDING, APPROVED, REJECTED
  final String? adminComment;
  final List<dynamic> originalData;
  final List<dynamic> proposedData;
  final String? createdAt;

  DarRequestItem({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userRole,
    this.userDept,
    required this.requestDate,
    required this.reason,
    required this.status,
    this.adminComment,
    required this.originalData,
    required this.proposedData,
    this.createdAt,
  });

  factory DarRequestItem.fromJson(Map<String, dynamic> json) {
    List<dynamic> parseJsonList(dynamic val) {
      if (val is List) return val;
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
      return [];
    }

    return DarRequestItem(
      requestId: json['request_id'] is int
          ? json['request_id']
          : int.tryParse(json['request_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name'] ?? json['userName'] ?? 'Employee',
      userEmail: json['user_email'] ?? json['email'],
      userRole: json['user_role'] ?? json['role'],
      userDept: json['user_dept'] ?? json['dept_name'] ?? json['department'],
      requestDate: json['request_date']?.toString().split('T').first ?? '',
      reason: json['reason'] ?? '',
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      adminComment: json['comment'] ?? json['admin_comment'] ?? json['review_comments'],
      originalData: parseJsonList(json['original_data']),
      proposedData: parseJsonList(json['proposed_data']),
      createdAt: json['created_at']?.toString(),
    );
  }
}

// [mod:2026-03-18T14:00:00+05:30]

// [upd:2026-05-01T17:00:00+05:30]
