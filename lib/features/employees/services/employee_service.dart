import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../shared/constants/api_constants.dart';
import '../models/employee_model.dart';
import '../../../../shared/services/auth_service.dart';

class EmployeeService {
  final AuthService _authService;
  
  // Use the Dio instance from AuthService to ensure authenticated requests
  Dio get _dio => _authService.dio;

  EmployeeService(this._authService);

  // 1. Get All Employees
  Future<List<Employee>> getEmployees() async {
    try {
      final response = await _dio.get('${ApiConstants.users}?workLocation=true');
      if (response.statusCode == 200 && response.data['success'] == true) { // Check success flag if API returns it
        // Adjust based on actual API response structure. Postman says:
        // { "success": true, "users": [...] }
        final List<dynamic> data = response.data['users'];
        return data.map((json) => Employee.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load employees: $e');
    }
  }

  // 2. Get Single Employee
  Future<Employee> getEmployee(int id) async {
    try {
      final response = await _dio.get('${ApiConstants.user}/$id');
      if (response.statusCode == 200) {
        return Employee.fromJson(response.data['user']);
      }
      throw Exception('User not found');
    } catch (e) {
      rethrow;
    }
  }

  // 3. Create Employee
  Future<void> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      await _dio.post(ApiConstants.user, data: employeeData);
    } catch (e) {
      throw Exception('Failed to create employee: ${e.toString()}');
    }
  }

  // 4. Update Employee
  Future<void> updateEmployee(int id, Map<String, dynamic> updates) async {
    try {
      await _dio.put('${ApiConstants.user}/$id', data: updates);
    } catch (e) {
      throw Exception('Failed to update employee: ${e.toString()}');
    }
  }

  // Toggle Active/Inactive Status
  Future<void> toggleUserStatus(int userId, bool isActive) async {
    try {
      await _dio.put('${ApiConstants.user}/$userId/status', data: {'is_active': isActive});
    } catch (e) {
      throw Exception('Failed to toggle status: $e');
    }
  }

  // Restore Soft-Deleted User
  Future<void> restoreUser(int userId) async {
    try {
      await _dio.post('${ApiConstants.user}/$userId/restore');
    } catch (e) {
      throw Exception('Failed to restore user: $e');
    }
  }

  // Force Delete (Permanently Cascade Delete)
  Future<void> forceDeleteUser(int userId) async {
    try {
      await _dio.delete('${ApiConstants.user}/$userId/force');
    } catch (e) {
      throw Exception('Failed to force delete user: $e');
    }
  }

  // 5. Delete Employee
  Future<void> deleteEmployee(int id) async {
    final endpoints = [
      '${ApiConstants.user}/$id',       // /admin/user/123
      '${ApiConstants.user}/$id/',      // /admin/user/123/
      '${ApiConstants.users}/$id',      // /admin/users/123
      '${ApiConstants.users}/$id/',     // /admin/users/123/
    ];

    DioException? lastError;

    for (final endpoint in endpoints) {
      try {
        await _dio.delete(endpoint);
        return; // Success!
      } on DioException catch (e) {
        lastError = e;
        // If 404, we continue to next endpoint. 
        // If other error (e.g. 500, 403), we might want to stop, but for now we try all just in case 403 is route-specific.
        if (e.response?.statusCode != 404) {
           // Optional: break here if we want to bubble up auth/server errors immediately,
           // but keeping it robust is safer for now.
        }
      } catch (e) {
         // Non-dio error
      }
    }

    // If we exhausted all endpoints
    if (lastError != null) {
      throw Exception('Failed to delete user. Tried endpoints: ${endpoints.map((e) => e.split('/').last).join(', ')}. Last Error: ${lastError.message} (Status: ${lastError.response?.statusCode})');
    } else {
      throw Exception('Failed to delete user: Unknown error');
    }
  }

  // 5b. Bulk Delete Employees
  Future<void> bulkDeleteEmployees(List<int> ids) async {
    try {
      await Future.wait(ids.map((id) => deleteEmployee(id)));
    } catch (e) {
      throw Exception('Failed to delete some employees: ${e.toString()}');
    }
  }
  
  // 6. Bulk Upload Users
  Future<Map<String, dynamic>> bulkUploadUsers(File file) async {
    try {
      String fileName = file.path.split(Platform.pathSeparator).last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post(
        ApiConstants.userBulkUpload, 
        data: formData,
      );
      
      return response.data;
    } catch (e) {
      throw Exception('Bulk upload failed: ${e.toString()}');
    }
  }

  // 7. Get My Work Locations
  Future<List<dynamic>> getMyWorkLocations() async {
    try {
      final response = await _dio.get(ApiConstants.employeeLocations);
      if (response.statusCode == 200) {
        return response.data['locations'] ?? [];
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch work locations: $e');
    }
  }
  
  // --- Dropdown Helpers ---

  Future<List<Department>> getDepartments() async {
    try {
      final res = await _dio.get(ApiConstants.departments);
      if (res.data['departments'] == null) return [];
      return (res.data['departments'] as List).map((x) => Department.fromJson(x)).toList();
    } catch (e) {
       return [];
    }
  }

  Future<List<Designation>> getDesignations() async {
    try {
      final res = await _dio.get(ApiConstants.designations);
      if (res.data['designations'] == null) return [];
      return (res.data['designations'] as List).map((x) => Designation.fromJson(x)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Shift>> getShifts() async {
    try {
      // Use Admin Shifts endpoint for dropdowns
      final res = await _dio.get(ApiConstants.adminShifts); 
      if (res.data['shifts'] == null) return [];
      return (res.data['shifts'] as List).map((x) => Shift.fromJson(x)).toList();
    } catch (e) {
      return [];
    }
  }
}
