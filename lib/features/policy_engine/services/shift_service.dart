import 'package:dio/dio.dart';
import '../models/shift_model.dart';
import '../../../shared/constants/api_constants.dart';

class ShiftService {
  final Dio _dio;

  ShiftService(this._dio);

  // 1. Get All Shifts
  Future<List<Shift>> getShifts() async {
    try {
      final response = await _dio.get(ApiConstants.policyShifts);
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> list = response.data['shifts'];
        return list.map((j) => Shift.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load shifts: $e');
    }
  }

  // 2. Create Shift
  Future<void> createShift(Shift shift) async {
    try {
      final payload = {
        'shift_name': shift.name,
        'start_time': shift.startTime,
        'end_time': shift.endTime,
        'grace_period_mins': shift.gracePeriodMins,
        'is_overtime_enabled': shift.isOvertimeEnabled,
        'overtime_threshold_hours': shift.overtimeThresholdHours,
        'policy_rules': shift.policyRules,
      };
      await _dio.post(ApiConstants.policyShifts, data: payload);
    } catch (e) {
      // Extract error message if available
      String msg = e.toString();
      if (e is DioException && e.response?.data != null && e.response!.data is Map) {
         msg = e.response!.data['message'] ?? msg;
      }
      throw Exception(msg);
    }
  }

  // 3. Update Shift
  Future<void> updateShift(int id, Shift shift) async {
    try {
      // API Spec for Update requires nested timing
      // Merge existing policy rules with timing
      final rules = Map<String, dynamic>.from(shift.policyRules);
      rules['shift_timing'] = {
        'start_time': shift.startTime,
        'end_time': shift.endTime
      };
      rules['grace_period'] = {
        'minutes': shift.gracePeriodMins
      };
      rules['overtime'] = {
        'enabled': shift.isOvertimeEnabled,
        'threshold': shift.overtimeThresholdHours,
        'buffer': shift.policyRules['overtime']?['buffer'] ?? 0.5
      };

      final payload = {
        'shift_name': shift.name,
        'grace_period_mins': shift.gracePeriodMins, 
        'is_overtime_enabled': shift.isOvertimeEnabled,
        'overtime_threshold_hours': shift.overtimeThresholdHours,
        'policy_rules': rules,
      };
      await _dio.put('${ApiConstants.policyShifts}/$id', data: payload);
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null && e.response!.data is Map) {
         msg = e.response!.data['message'] ?? msg;
      }
      throw Exception(msg);
    }
  }

  // 4. Delete Shift
  Future<void> deleteShift(int id) async {
    try {
      await _dio.delete('${ApiConstants.policyShifts}/$id');
    } catch (e) {
       String msg = e.toString();
      if (e is DioException && e.response?.data != null && e.response!.data is Map) {
         msg = e.response!.data['message'] ?? msg;
      }
      throw Exception(msg);
    }
  }
}
