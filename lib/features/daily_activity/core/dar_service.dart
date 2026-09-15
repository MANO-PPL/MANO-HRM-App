import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/daily_activity/core/dar_models.dart';

class DarService {
  final Dio _dio;

  DarService(this._dio);

  // 1. Get Activities (Tasks) for a Date Range
  Future<List<DarActivity>> getActivities({required String dateFrom, required String dateTo}) async {
    try {
      final response = await _dio.get(
        ApiConstants.darActivitiesList,
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
        },
      );
      if (response.statusCode == 200 && response.data['ok'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => DarActivity.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("DarService getActivities error: $e");
      return [];
    }
  }

  // 1.1 Get Activities (Tasks) for a Single Date
  Future<List<DarActivity>> getActivitiesForDate(String date) async {
    try {
      final response = await _dio.get(
        ApiConstants.darActivitiesList,
        queryParameters: {
          'date': date,
        },
      );
      if (response.statusCode == 200 && response.data['ok'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => DarActivity.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("DarService getActivitiesForDate error: $e");
      return [];
    }
  }

  // 2. Get Events (Meetings & Events) for a Date Range
  Future<List<DarEvent>> getEvents({required String dateFrom, required String dateTo}) async {
    try {
      final response = await _dio.get(
        ApiConstants.darEventsList,
        queryParameters: {
          'date_from': dateFrom,
          'date_to': dateTo,
        },
      );
      if (response.statusCode == 200 && response.data['ok'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => DarEvent.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("DarService getEvents error: $e");
      return [];
    }
  }

  // 3. Get Settings Categories
  Future<List<String>> getCategories() async {
    try {
      final response = await _dio.get(ApiConstants.darSettingsList);
      if (response.statusCode == 200 && response.data['ok'] == true) {
        final categories = response.data['data']?['categories'];
        if (categories is List) {
          return List<String>.from(categories);
        }
      }
      return ['General'];
    } catch (e) {
      debugPrint("DarService getCategories error: $e");
      return ['General']; // Fallback
    }
  }

  // 4. Save Activity (Create or Update)
  Future<DarActivity> saveActivity(DarActivity activity) async {
    try {
      final payload = activity.toJson();
      if (activity.activityId == null) {
        final response = await _dio.post(ApiConstants.darActivitiesCreate, data: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data['data'] ?? response.data;
          return DarActivity.fromJson(data);
        }
      } else {
        final response = await _dio.put(
          '${ApiConstants.darActivitiesUpdate}/${activity.activityId}',
          data: payload,
        );
        if (response.statusCode == 200) {
          final data = response.data['data'] ?? response.data;
          return DarActivity.fromJson(data);
        }
      }
      throw Exception("Failed to save activity");
    } catch (e) {
      debugPrint("DarService saveActivity error: $e");
      rethrow;
    }
  }

  // 4.1 Batch Save Activities (Advance task planning)
  Future<Map<String, dynamic>> batchSaveActivities({
    required String activityDate,
    required List<DarActivity> tasks,
  }) async {
    try {
      final taskPayloads = tasks.map((t) {
        return {
          if (t.activityId != null) 'id': t.activityId,
          'start_time': t.startTime,
          'end_time': t.endTime,
          'title': t.title,
          'description': t.description,
          'activity_type': t.activityType,
          'status': t.status,
        };
      }).toList();

      final response = await _dio.post(
        ApiConstants.darActivitiesBatchSave,
        data: {
          'activity_date': activityDate,
          'tasks': taskPayloads,
        },
      );
      return response.data is Map ? Map<String, dynamic>.from(response.data) : {'ok': true};
    } catch (e) {
      debugPrint("DarService batchSaveActivities error: $e");
      rethrow;
    }
  }

  // 5. Delete Activity
  Future<void> deleteActivity(int activityId) async {
    try {
      final response = await _dio.delete('${ApiConstants.darActivitiesDelete}/$activityId');
      if (response.statusCode != 200 && response.data['ok'] != true) {
        throw Exception("Failed to delete activity");
      }
    } catch (e) {
      debugPrint("DarService deleteActivity error: $e");
      rethrow;
    }
  }

  // 6. Save Event (Create or Update)
  Future<DarEvent> saveEvent(DarEvent event) async {
    try {
      final payload = event.toJson();
      if (event.eventId == null) {
        final response = await _dio.post(ApiConstants.darEventsCreate, data: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = response.data['data'] ?? response.data;
          return DarEvent.fromJson(data);
        }
      } else {
        final response = await _dio.put(
          '${ApiConstants.darEventsUpdate}/${event.eventId}',
          data: payload,
        );
        if (response.statusCode == 200) {
          final data = response.data['data'] ?? response.data;
          return DarEvent.fromJson(data);
        }
      }
      throw Exception("Failed to save event");
    } catch (e) {
      debugPrint("DarService saveEvent error: $e");
      rethrow;
    }
  }

  // 7. Delete Event
  Future<void> deleteEvent(int eventId) async {
    try {
      final response = await _dio.delete('${ApiConstants.darEventsDelete}/$eventId');
      if (response.statusCode != 200 && response.data['ok'] != true) {
        throw Exception("Failed to delete event");
      }
    } catch (e) {
      debugPrint("DarService deleteEvent error: $e");
      rethrow;
    }
  }

  // 8. Submit correction request for past dates
  Future<void> submitRequest({
    required String date,
    required String reason,
    required List<Map<String, dynamic>> originalData,
    required List<Map<String, dynamic>> proposedData,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.darRequestsCreate,
        data: {
          'request_date': date,
          'reason': reason,
          'original_data': originalData,
          'proposed_data': proposedData,
        },
      );
      if (response.statusCode != 200 && response.data['ok'] != true) {
        throw Exception(response.data['message'] ?? "Failed to submit request");
      }
    } catch (e) {
      debugPrint("DarService submitRequest error: $e");
      rethrow;
    }
  }
}

// [mod:2026-03-18T14:00:00+05:30]

// [upd:2026-05-11T17:00:00+05:30]
