import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';

class FeedbackService {
  final Dio _dio;

  FeedbackService(this._dio);

  // 1. Submit Feedback
  Future<void> submitFeedback({
    required String title,
    required String description,
    required String type, // 'BUG', 'FEATURE', etc
    List<File>? files,
  }) async {
    try {
      Map<String, dynamic> map = {
        "title": title,
        "description": description,
        "type": type,
      };
      
      if (files != null && files.isNotEmpty) {
        // Handle multiple files if backend API supports array for 'files' key
        // Note: Dio FormData needs careful handling for arrays of files
        // Often it's equivalent to adding multiple entries with same key 'files'
        map['files'] = [
          for (var file in files)
            await MultipartFile.fromFile(file.path, filename: file.path.split('/').last)
        ];
      }

      FormData formData = FormData.fromMap(map);

      await _dio.post(ApiConstants.feedback, data: formData);
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // 2. Get All Feedback (Admin)
  Future<List<dynamic>> getAllFeedback({String status = 'OPEN', String type = 'BUG', int limit = 50}) async {
    try {
      final response = await _dio.get(ApiConstants.feedback, queryParameters: {
        'status': status,
        'type': type,
        'limit': limit,
      });
      if (response.statusCode == 200 && response.data['ok'] == true) {
        return response.data['data'] ?? [];
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch feedback: $e');
    }
  }

  // 3. Update Feedback Status (Admin)
  Future<void> updateFeedbackStatus(int id, String status) async {
    try {
      await _dio.patch(
        ApiConstants.feedbackStatus.replaceAll(':id', id.toString()), 
        data: {'status': status}
      );
    } catch (e) {
      throw Exception('Failed to update feedback status: $e');
    }
  }
}
