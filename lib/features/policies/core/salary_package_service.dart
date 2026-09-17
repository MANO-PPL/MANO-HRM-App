import 'package:dio/dio.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';

class SalaryPackageService {
  final Dio _dio;

  SalaryPackageService(this._dio);

  /// 1. Get all active and non-deleted package groups for current org with resolved active rates
  Future<List<Map<String, dynamic>>> getPackageGroups() async {
    try {
      final response = await _dio.get(ApiConstants.payrollPackages);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw _handleError(e, 'Failed to load salary packages');
    }
  }

  /// 2. Get all employees with their active package assignments
  Future<List<Map<String, dynamic>>> getEmployeesWithPackages() async {
    try {
      final response = await _dio.get(ApiConstants.payrollEmployeesPackages);
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw _handleError(e, 'Failed to load employee package assignments');
    }
  }

  /// 3. Create a new package group and initial revision in the database
  Future<Map<String, dynamic>> createPackageGroup({
    required String packageName,
    required double grossSalary,
    required bool overtimeEnabled,
    required double overtimeRate,
    required String effectiveFrom,
  }) async {
    try {
      final payload = {
        'packageName': packageName,
        'grossSalary': grossSalary,
        'overtimeEnabled': overtimeEnabled,
        'overtimeRate': overtimeRate,
        'effectiveFrom': effectiveFrom,
      };
      final response = await _dio.post(ApiConstants.payrollPackages, data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Map<String, dynamic>.from(response.data['data'] ?? {});
      }
      throw Exception('Failed to create salary package');
    } catch (e) {
      throw _handleError(e, 'Failed to create salary package');
    }
  }

  /// 4. Update an existing package group
  Future<Map<String, dynamic>> updatePackageGroup(
    dynamic packageGroupId, {
    String? packageName,
    bool? isActive,
    double? grossSalary,
    bool? overtimeEnabled,
    double? overtimeRate,
    String? effectiveFrom,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (packageName != null) payload['packageName'] = packageName;
      if (isActive != null) payload['isActive'] = isActive;
      if (grossSalary != null) payload['grossSalary'] = grossSalary;
      if (overtimeEnabled != null) payload['overtimeEnabled'] = overtimeEnabled;
      if (overtimeRate != null) payload['overtimeRate'] = overtimeRate;
      if (effectiveFrom != null) payload['effectiveFrom'] = effectiveFrom;

      final response = await _dio.put('${ApiConstants.payrollPackages}/$packageGroupId', data: payload);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data['data'] ?? {});
      }
      throw Exception('Failed to update salary package');
    } catch (e) {
      throw _handleError(e, 'Failed to update salary package');
    }
  }

  /// 5. Delete a package group from database
  Future<void> deletePackageGroup(dynamic packageGroupId) async {
    try {
      final response = await _dio.delete('${ApiConstants.payrollPackages}/$packageGroupId');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete salary package');
      }
    } catch (e) {
      throw _handleError(e, 'Failed to delete salary package');
    }
  }

  /// 6. Get revision history for a package group
  Future<List<Map<String, dynamic>>> getPackageRevisions(dynamic packageGroupId) async {
    try {
      final response = await _dio.get('${ApiConstants.payrollPackages}/$packageGroupId/revisions');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw _handleError(e, 'Failed to load package revisions');
    }
  }

  Exception _handleError(dynamic e, String fallbackMsg) {
    if (e is DioException) {
      if (e.response?.data != null && e.response!.data is Map) {
        final data = e.response!.data as Map;
        final msg = data['message'] ?? data['error'] ?? fallbackMsg;
        return Exception(msg.toString());
      }
      if (e.message != null && e.message!.isNotEmpty) {
        return Exception(e.message);
      }
    }
    return Exception(e.toString().replaceAll('Exception: ', ''));
  }
}
