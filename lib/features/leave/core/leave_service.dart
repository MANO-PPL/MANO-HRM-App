import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/shared/utils/error_helper.dart';

class LeaveService {
  final Dio _dio;

  LeaveService(this._dio);

  // 1. Get My History
  Future<List<LeaveRequest>> getMyHistory() async {
    try {
      final response = await _dio.get(ApiConstants.leavesMyHistory);
      debugPrint('LeaveService (RAW): ${response.data}');
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> leavesJson = response.data['leaves'] ?? [];
        return leavesJson.map((e) => LeaveRequest.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch leave history: $e');
    }
  }

  // 2. Submit Leave Request
  Future<void> submitLeaveRequest(Map<String, dynamic> requestData) async {
    try {
      final map = <String, dynamic>{
        'leave_type': requestData['leave_type']?.toString() ?? '',
        'start_date': requestData['start_date']?.toString() ?? '',
        'end_date': requestData['end_date']?.toString() ?? '',
        'reason': requestData['reason']?.toString() ?? '',
      };
      if (requestData['rule_id'] != null) {
        map['rule_id'] = requestData['rule_id'].toString();
      }

      final formData = FormData.fromMap(map);

      if (requestData.containsKey('attachments') && requestData['attachments'] != null) {
        final List<dynamic> attachments = requestData['attachments'] is List
            ? requestData['attachments']
            : [requestData['attachments']];

        for (var attachment in attachments) {
          final isFile = attachment is PlatformFile ||
              attachment.runtimeType.toString().contains('PlatformFile');
          if (isFile) {
            final dynamic file = attachment;
            if (file.bytes != null) {
              formData.files.add(MapEntry(
                'attachments',
                MultipartFile.fromBytes(file.bytes!, filename: file.name),
              ));
            } else if (file.path != null) {
              formData.files.add(MapEntry(
                'attachments',
                await MultipartFile.fromFile(file.path!, filename: file.name),
              ));
            }
          }
        }
      }

      final response = await _dio.post(
        ApiConstants.leavesRequest,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map && (response.data['ok'] == false || response.data['success'] == false)) {
        final msg = response.data['message'] ?? response.data['error'];
        throw Exception(msg?.toString() ?? 'Failed to submit leave request');
      }
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? (e.response?.data['message'] ?? e.response?.data['error'])?.toString()
          : null;
      if (serverMsg != null && serverMsg.trim().isNotEmpty) {
        throw Exception(serverMsg.trim());
      }
      throw Exception(friendlyError(e, fallback: 'Failed to submit leave request'));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  // 3. Withdraw Request
  Future<void> withdrawRequest(int id) async {
      try {
        final url = '${ApiConstants.leavesRequest}/$id';
        debugPrint('LeaveService: Withdrawing request at $url (ID: $id)');
        await _dio.delete(url);
      } catch (e) {
        if (e is DioException) {
           throw Exception('Failed to withdraw request: ${e.response?.statusCode} - ${e.response?.data}');
        }
        rethrow;
      }
  }

  // 4. Admin - Pending Requests
  Future<List<LeaveRequest>> getPendingRequests() async {
    try {
      final response = await _dio.get(ApiConstants.leavesAdminPending);
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> hitsJson = response.data['requests'] ?? [];
        return hitsJson.map((e) => LeaveRequest.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch pending requests: $e');
    }
  }

  // 5. Admin - History
  Future<List<LeaveRequest>> getAdminHistory({int? userId, String? status, DateTime? startDate, DateTime? endDate}) async {
    try {
      final Map<String, dynamic> query = {};
      
      if (userId != null) query['user_id'] = userId;
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;
      if (startDate != null) query['start_date'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) query['end_date'] = endDate.toIso8601String().split('T')[0];

      final response = await _dio.get(ApiConstants.leavesAdminHistory, queryParameters: query);
      
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
         // The user sample had "history" key
        final List<dynamic> hitsJson = response.data['history'] ?? [];
        return hitsJson.map((e) => LeaveRequest.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch admin leave history: $e');
    }
  }

  // 6. Admin - Approve/Reject (Update Status)
  Future<void> updateRequestStatus(int id, String status, {String? payType, int? payPercentage, String? comment}) async {
    try {
      final data = {
        'status': status,
        if (payType != null) 'pay_type': payType,
        if (payPercentage != null) 'pay_percentage': payPercentage,
        if (comment != null) 'admin_comment': comment,
      };
      
      await _dio.put('${ApiConstants.leavesAdminStatus}/$id', data: data);
    } catch (e) {
      if (e is DioException) {
         throw Exception('Failed to update request status: ${e.response?.data ?? e.message}');
      }
      throw Exception('Failed to update request status: $e');
    }
  }

  // 7. Get My Leave Balances
  Future<List<Map<String, dynamic>>> getMyLeaveBalances({int? year}) async {
    try {
      final params = <String, dynamic>{};
      if (year != null) params['year'] = year;
      final response = await _dio.get(ApiConstants.leavesMyBalances, queryParameters: params.isNotEmpty ? params : null);
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> raw = response.data['balances'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('LeaveService.getMyLeaveBalances error: $e');
      return [];
    }
  }

  // 8. Admin - Get Specific Employee's Leave Balance
  Future<List<Map<String, dynamic>>> getEmployeeLeaveBalance(int userId, {int? year}) async {
    try {
      final params = <String, dynamic>{};
      if (year != null) params['year'] = year;
      final response = await _dio.get(
        '${ApiConstants.leavesEmployeeBalance}/$userId',
        queryParameters: params.isNotEmpty ? params : null,
      );
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> raw = response.data['balances'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('LeaveService.getEmployeeLeaveBalance error: $e');
      return [];
    }
  }

  // 9. Admin - Get All Employees Leave Balances
  Future<List<Map<String, dynamic>>> getAllEmployeesLeaveBalances({int? year, int? ruleId}) async {
    try {
      final params = <String, dynamic>{};
      if (year != null) params['year'] = year;
      if (ruleId != null) params['rule_id'] = ruleId;
      final response = await _dio.get(
        ApiConstants.leavesBalancesAll,
        queryParameters: params.isNotEmpty ? params : null,
      );
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> raw = response.data['balances'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('LeaveService.getAllEmployeesLeaveBalances error: $e');
      return [];
    }
  }

  // 10. Get Leave Policies (with rules)
  Future<List<Map<String, dynamic>>> getMyLeavePolicies() async {
    try {
      final response = await _dio.get(ApiConstants.leavesPolicies);
      if (response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true)) {
        final List<dynamic> raw = response.data['policies'] ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('LeaveService.getMyLeavePolicies error: $e');
      return [];
    }
  }

  // 11. Admin - Assign Policy to Employees
  Future<bool> assignPolicyToEmployees(int policyId, {required List<int> userIds, required int year}) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.leavesPolicies}/$policyId/assign',
        data: {
          'user_ids': userIds,
          'year': year,
        },
      );
      return response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true);
    } catch (e) {
      debugPrint('LeaveService.assignPolicyToEmployees error: $e');
      rethrow;
    }
  }

  // 12. Admin - Delete/Unassign Leave Balance
  Future<bool> deleteLeaveBalance(int balanceId) async {
    try {
      final response = await _dio.delete('${ApiConstants.leavesEmployeeBalance}/$balanceId');
      return response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true);
    } catch (e) {
      debugPrint('LeaveService.deleteLeaveBalance error: $e');
      rethrow;
    }
  }

  // 13. Admin - Update/Adjust Employee Leave Balance (matching web AdjustBalanceDrawer)
  Future<bool> updateLeaveBalance(
    int balanceId, {
    required double allocated,
    double carriedForward = 0,
    double used = 0,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.leavesEmployeeBalance}/$balanceId',
        data: {
          'allocated': allocated,
          'carried_forward': carriedForward,
          'used': used,
        },
      );
      return response.statusCode == 200 && (response.data['ok'] == true || response.data['success'] == true);
    } catch (e) {
      debugPrint('LeaveService.updateLeaveBalance error: $e');
      rethrow;
    }
  }
}

// commit-marker: 2026-02-20T09:15:00+05:30

// [mod:2026-02-20T09:15:00+05:30]

// [upd:2026-05-02T09:00:00+05:30]
