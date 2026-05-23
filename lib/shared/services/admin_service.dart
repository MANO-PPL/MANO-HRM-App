import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../../shared/services/auth_service.dart';
import '../models/dashboard_model.dart'; 

class AdminService {
  final AuthService _authService;

  AdminService(this._authService);

  Future<DashboardData> getDashboardStats({
    String range = 'weekly',
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = {
        'range': range,
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      };

      final response = await _authService.dio.get(
        ApiConstants.dashboardStats,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = DashboardData.fromJson(response.data);

        // Fallback: If no activities are returned from the main stats,
        // fetch real-time attendance to populate the feed (similar to web)
        if (data.activities.isEmpty) {
          try {
            final todayStr = DateTime.now().toIso8601String().split('T')[0];
            final attendanceResponse = await _authService.dio.get(
              ApiConstants.adminAttendanceRecords,
              queryParameters: {
                'date_from': todayStr,
                'date_to': todayStr,
                'limit': 200,
              },
            );

            if (attendanceResponse.statusCode == 200 &&
                attendanceResponse.data != null &&
                attendanceResponse.data['ok'] == true) {
              final List<dynamic> list = attendanceResponse.data['data'] ?? [];
              final fallbackActivities = list.map((record) {
                final timeStr = record['time_out'] ?? record['time_in'] ?? '';
                String formattedTime = '';
                if (timeStr.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(timeStr);
                    formattedTime = DateFormat('hh:mm a').format(dt.toLocal());
                  } catch (_) {
                    formattedTime = timeStr;
                  }
                }

                return ActivityLog(
                  id: 'att-${record['attendance_id']}',
                  user: record['user_name'] ?? 'Unknown',
                  role: record['designation'] ?? 'Staff',
                  action: record['time_out'] != null ? 'Checked Out' : 'Checked In',
                  time: formattedTime,
                  type: record['time_out'] != null ? 'check-out' : 'check-in',
                );
              }).toList();

              return DashboardData(
                stats: data.stats,
                trends: data.trends,
                chartData: data.chartData,
                activities: fallbackActivities.take(10).toList(),
              );
            }
          } catch (attError) {
            debugPrint("Failed to fetch fallback activities in AdminService: $attError");
          }
        }

        return data;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load dashboard stats');
      }
    } catch (e) {
      rethrow;
    }
  }
}
