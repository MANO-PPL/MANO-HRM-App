import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  final Dio _dio;

  ChatService(this._dio);

  // 1. Fetch Rooms list
  Future<List<ChatRoom>> getRooms() async {
    try {
      final response = await _dio.get('/collaboration/rooms');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ChatRoom.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getRooms error: $e");
      return [];
    }
  }

  // 2. Fetch Directory / Coworkers list (excluding bots/AI accounts)
  Future<List<ChatMember>> getCoworkers() async {
    try {
      final response = await _dio.get('/collaboration/users');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        final list = data.map((json) => ChatMember.fromJson(json)).toList();
        
        // Filter out AI accounts
        return list.where((u) {
          final name = u.userName.toLowerCase();
          final type = u.userType?.toLowerCase() ?? '';
          return !(name.contains('bot') ||
              name.contains('assistant') ||
              name.contains('ai') ||
              type.contains('bot') ||
              type.contains('ai'));
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getCoworkers error: $e");
      return [];
    }
  }

  // 3. Fetch Message History
  Future<List<ChatMessage>> getMessages(int roomId) async {
    try {
      final response = await _dio.get('/collaboration/rooms/$roomId/messages');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ChatMessage.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("ChatService getMessages error: $e");
      return [];
    }
  }

  // 4. Send Chat Message
  Future<ChatMessage?> sendMessage(int roomId, String messageText, Map<String, dynamic>? attachment) async {
    try {
      final response = await _dio.post(
        '/collaboration/rooms/$roomId/messages',
        data: {
          'message_text': messageText,
          'attachment': attachment,
        },
      );
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data['success'] == true) {
        return ChatMessage.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService sendMessage error: $e");
      return null;
    }
  }

  // 5. Upload Attachment
  Future<Map<String, dynamic>?> uploadAttachment(int roomId, String filePath, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post(
        '/collaboration/rooms/$roomId/upload',
        data: formData,
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['file']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService uploadAttachment error: $e");
      return null;
    }
  }

  // 6. Create Chat Room (Group or DM)
  Future<ChatRoom?> createRoom({
    required String type, // 'direct' | 'group'
    required List<int> memberIds,
    String? roomName,
  }) async {
    try {
      final payload = {
        'room_type': type,
        'member_ids': memberIds,
      };
      if (roomName != null && roomName.trim().isNotEmpty) {
        payload['room_name'] = roomName;
      }
      final response = await _dio.post('/collaboration/rooms', data: payload);
      if ((response.statusCode == 200 || response.statusCode == 201) && (response.data['success'] == true || response.data['ok'] == true)) {
        final roomData = response.data['data'] ?? response.data['room'] ?? response.data;
        return ChatRoom.fromJson(roomData);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService createRoom error: $e");
      return null;
    }
  }

  // 7. Update Group Members
  Future<ChatRoom?> updateMembers(int roomId, List<int> memberIds) async {
    try {
      final response = await _dio.put(
        '/collaboration/rooms/$roomId/members',
        data: {
          'member_ids': memberIds,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        return ChatRoom.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint("ChatService updateMembers error: $e");
      return null;
    }
  }

  // 8. Mark Room as Read
  Future<bool> markAsRead(int roomId) async {
    try {
      final response = await _dio.put('/collaboration/rooms/$roomId/read');
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      debugPrint("ChatService markAsRead error: $e");
      return false;
    }
  }
}
