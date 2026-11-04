import 'dart:convert';

class ChatMember {
  final int userId;
  final String userName;
  final String? email;
  final String? profileImage;
  final String? userType;

  ChatMember({
    required this.userId,
    required this.userName,
    this.email,
    this.profileImage,
    this.userType,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    String name = json['user_name'] ?? json['username'] ?? json['userName'] ?? '';
    if (name.startsWith('@')) {
      name = name.substring(1);
    }
    return ChatMember(
      userId: json['user_id'] is String 
          ? (int.tryParse(json['user_id']) ?? 0) 
          : (json['user_id'] ?? json['userId'] ?? 0),
      userName: name,
      email: json['email'],
      profileImage: json['profile_image'] ?? json['profile_image_url'] ?? json['profileImageUrl'],
      userType: json['user_type'] ?? json['userType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'email': email,
      'profile_image': profileImage,
      'user_type': userType,
    };
  }
}

class ChatMessage {
  final dynamic messageId; // int or String (for optimistic ID)
  final int roomId;
  final int senderId;
  final String messageText;
  final Map<String, dynamic>? attachment; // { name, url, size, type, duration }
  final Map<String, dynamic>? replyTo; // { message_id, user_name, message_text, attachment }
  final String createdAt;
  final String? userName;
  final String? profileImageUrl;
  String? status; // 'sending' | 'sent' | 'failed'

  ChatMessage({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    required this.messageText,
    this.attachment,
    this.replyTo,
    required this.createdAt,
    this.userName,
    this.profileImageUrl,
    this.status = 'sent',
  });

  bool get isVoiceNote {
    if (attachment == null) return false;
    final type = (attachment!['type'] ?? '').toString().toLowerCase();
    final name = (attachment!['name'] ?? '').toString().toLowerCase();
    return type.contains('audio') || name.endsWith('.mp3') || name.endsWith('.m4a') || name.endsWith('.aac') || name.endsWith('.wav') || name.endsWith('.opus');
  }

  bool get isImageAttachment {
    if (attachment == null) return false;
    final type = (attachment!['type'] ?? '').toString().toLowerCase();
    final name = (attachment!['name'] ?? '').toString().toLowerCase();
    return type.contains('image') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.gif') || name.endsWith('.webp');
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String? name = json['user_name'] ?? json['sender_name'] ?? json['userName'] ?? json['senderName'];
    if (name != null && name.startsWith('@')) {
      name = name.substring(1);
    }

    Map<String, dynamic>? parsedAttachment;
    if (json['attachment'] != null) {
      if (json['attachment'] is Map) {
        parsedAttachment = Map<String, dynamic>.from(json['attachment']);
      } else if (json['attachment'] is String && (json['attachment'] as String).isNotEmpty) {
        try {
          parsedAttachment = Map<String, dynamic>.from(jsonDecode(json['attachment']));
        } catch (_) {}
      }
    }

    Map<String, dynamic>? parsedReplyTo;
    if (json['reply_to'] != null || json['replyTo'] != null) {
      final rData = json['reply_to'] ?? json['replyTo'];
      if (rData is Map) {
        parsedReplyTo = Map<String, dynamic>.from(rData);
      } else if (rData is String && rData.isNotEmpty) {
        try {
          parsedReplyTo = Map<String, dynamic>.from(jsonDecode(rData));
        } catch (_) {}
      }
    }

    return ChatMessage(
      messageId: json['message_id'] ?? json['id'] ?? json['messageId'],
      roomId: json['room_id'] is String 
          ? (int.tryParse(json['room_id']) ?? 0) 
          : (json['room_id'] ?? json['roomId'] ?? 0),
      senderId: json['sender_id'] is String 
          ? (int.tryParse(json['sender_id']) ?? 0) 
          : (json['sender_id'] ?? json['senderId'] ?? 0),
      messageText: json['message_text'] ?? json['messageText'] ?? json['message'] ?? json['text'] ?? '',
      attachment: parsedAttachment,
      replyTo: parsedReplyTo,
      createdAt: json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String(),
      userName: name,
      profileImageUrl: json['profile_image_url'] ?? json['profile_image'] ?? json['profileImageUrl'],
      status: json['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'room_id': roomId,
      'sender_id': senderId,
      'message_text': messageText,
      'attachment': attachment,
      'reply_to': replyTo,
      'created_at': createdAt,
      'user_name': userName,
      'profile_image_url': profileImageUrl,
      'status': status,
    };
  }

  // Helper to format system card message or return normal text
  String get displayPreview {
    if (messageText.startsWith("[SYSTEM_CARD:")) {
      final endHeaderIndex = messageText.indexOf("]");
      if (endHeaderIndex != -1) {
        final header = messageText.substring(13, endHeaderIndex);
        final parts = header.split(":");
        final cardType = parts[0];
        final cardStatus = parts.length > 2 ? parts[2] : "";

        final body = messageText.substring(endHeaderIndex + 1).trim();
        Map<String, dynamic>? payload;
        try {
          payload = jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {}

        if (cardType == 'leave_request') {
          if (payload != null) {
            final name = payload['employee_name'] ?? payload['reviewer_name'] ?? "Employee";
            return "Leave: ${payload['leave_type']} ($cardStatus) - $name";
          }
          return "Leave Request ($cardStatus)";
        } else if (cardType == 'correction_request') {
          if (payload != null) {
            final name = payload['employee_name'] ?? payload['reviewer_name'] ?? "Employee";
            return "Correction: ${payload['correction_type']} ($cardStatus) - $name";
          }
          return "Correction Request ($cardStatus)";
        } else if (cardType == 'shift_assign') {
          if (payload != null) {
            return "Shift Assigned: ${payload['shift_name']} (${payload['start_time']} - ${payload['end_time']})";
          }
          return "Shift Assigned";
        } else if (cardType == 'geofence_assign') {
          if (payload != null) {
            return "Location Assigned: ${payload['location_name']}";
          }
          return "Location Assigned";
        } else if (cardType == 'group_update') {
          return body;
        }
      }
    }
    return messageText;
  }
}

class ChatRoom {
  final int roomId;
  final String roomType; // 'direct' | 'group'
  final String? roomName;
  final String createdAt;
  final ChatMessage? lastMessage;
  int unreadCount;
  final List<ChatMember> members;
  final String? avatarUrl;

  ChatRoom({
    required this.roomId,
    required this.roomType,
    this.roomName,
    required this.createdAt,
    this.lastMessage,
    required this.unreadCount,
    required this.members,
    this.avatarUrl,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final membersList = json['members'] is List
        ? (json['members'] as List).map((m) => ChatMember.fromJson(m)).toList()
        : <ChatMember>[];
    String? rName = json['room_name'] ?? json['roomName'];
    if (rName != null && rName.startsWith('@')) {
      rName = rName.substring(1);
    }
    return ChatRoom(
      roomId: json['room_id'] is String 
          ? (int.tryParse(json['room_id']) ?? 0) 
          : (json['room_id'] ?? json['roomId'] ?? 0),
      roomType: json['room_type'] ?? json['roomType'] ?? 'direct',
      roomName: rName,
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      lastMessage: (json['last_message'] ?? json['lastMessage']) != null
          ? ChatMessage.fromJson(json['last_message'] ?? json['lastMessage'])
          : null,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      members: membersList,
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'room_type': roomType,
      'room_name': roomName,
      'created_at': createdAt,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'members': members.map((m) => m.toJson()).toList(),
      'avatar_url': avatarUrl,
    };
  }

  // Get dynamic room display name
  String getRoomDisplayName(int currentUserId) {
    if (roomType == 'direct') {
      final otherMember = members.firstWhere(
        (m) => m.userId != currentUserId && m.userId != 0,
        orElse: () => ChatMember(userId: 0, userName: ''),
      );
      if (otherMember.userName.isNotEmpty && otherMember.userName != 'Deleted User') {
        return otherMember.userName;
      }
      if (roomName != null && roomName!.trim().isNotEmpty && roomName != 'Direct Message') {
        return roomName!;
      }
      if (otherMember.userName.isNotEmpty) {
        return otherMember.userName;
      }
      return 'Direct Message';
    }
    return (roomName != null && roomName!.trim().isNotEmpty) ? roomName! : 'Group Chat';
  }

  // Get dynamic room display avatar
  String? getRoomDisplayAvatar(int currentUserId) {
    if (roomType == 'direct') {
      final otherMember = members.firstWhere(
        (m) => m.userId != currentUserId && m.userId != 0,
        orElse: () => ChatMember(userId: 0, userName: ''),
      );
      if (otherMember.profileImage != null && otherMember.profileImage!.isNotEmpty) {
        return otherMember.profileImage;
      }
      return avatarUrl;
    }
    return avatarUrl;
  }
}

extension ChatStringExtension on String {
  String get initials {
    final trimmed = trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    try {
      if (parts.length == 1) {
        final w = parts[0];
        return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
      }
      final first = parts[0].isNotEmpty ? parts[0].substring(0, 1) : '?';
      final second = parts[1].isNotEmpty ? parts[1].substring(0, 1) : '';
      return '$first$second'.toUpperCase();
    } catch (_) {
      return '?';
    }
  }
}

// [mod:2026-02-23T14:00:00+05:30]

// [upd:2026-05-06T11:30:00+05:30]
