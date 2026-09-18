import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';

class LabourMonthlyGridResult {
  final List<LabourMonthlyRow> grid;
  final LabourMonthDetails? monthDetails;

  LabourMonthlyGridResult({
    required this.grid,
    this.monthDetails,
  });
}

class LabourFinancesResult {
  final List<LabourPayoutSummary> summary;
  final LabourMonthDetails? monthDetails;

  LabourFinancesResult({
    required this.summary,
    this.monthDetails,
  });
}

class LabourService {
  final Dio _dio;

  LabourService(this._dio);

  String _formatErrorMessage(dynamic error, String fallback) {
    if (error is DioException) {
      if (error.response?.data != null && error.response?.data is Map) {
        final msg = error.response?.data['message'] ?? error.response?.data['error'];
        if (msg != null && msg.toString().isNotEmpty) {
          return msg.toString();
        }
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }
    return fallback;
  }

  // ==========================================
  // 1. SITES CRUD
  // ==========================================

  Future<List<LabourSite>> getAllSites() async {
    try {
      final response = await _dio.get(ApiConstants.labourSites);
      if (response.statusCode == 200) {
        final list = response.data['sites'] as List? ?? [];
        return list.map((item) => LabourSite.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      throw Exception('Failed to fetch construction sites');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch sites from database'));
    }
  }

  // Backward compatibility alias
  Future<List<LabourSite>> getSites() => getAllSites();

  Future<int> createSite({
    required String siteName,
    String? locationDetails,
    String status = 'Active',
    String? endDate,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourSites,
        data: {
          'site_name': siteName,
          'location_details': locationDetails,
          'status': status,
          if (endDate != null) 'end_date': endDate,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['site_id'] != null
            ? int.tryParse(response.data['site_id'].toString()) ?? 0
            : 0;
      }
      throw Exception('Failed to create site');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to create site'));
    }
  }

  Future<bool> updateSite({
    required int siteId,
    required String siteName,
    String? locationDetails,
    required String status,
    String? endDate,
  }) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.labourSites}/$siteId',
        data: {
          'site_name': siteName,
          'location_details': locationDetails,
          'status': status,
          if (endDate != null) 'end_date': endDate,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to update site'));
    }
  }

  Future<bool> deleteSite(int siteId) async {
    try {
      final response = await _dio.delete('${ApiConstants.labourSites}/$siteId');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to delete site'));
    }
  }

  // ==========================================
  // 2. LABOUR WORKERS CRUD
  // ==========================================

  Future<List<LabourWorker>> getAllLabours() async {
    try {
      final response = await _dio.get(ApiConstants.labourLabours);
      if (response.statusCode == 200) {
        final list = response.data['labours'] as List? ?? [];
        return list.map((item) => LabourWorker.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      throw Exception('Failed to fetch labour workforce');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch labour workforce from database'));
    }
  }

  // Backward compatibility alias
  Future<List<LabourWorker>> getLabours() => getAllLabours();

  Future<int> createLabour(Map<String, dynamic> workerData) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourLabours,
        data: workerData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['labour_id'] != null
            ? int.tryParse(response.data['labour_id'].toString()) ?? 0
            : 0;
      }
      throw Exception('Failed to register worker');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to create worker'));
    }
  }

  Future<bool> updateLabour(int labourId, Map<String, dynamic> workerData) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.labourLabours}/$labourId',
        data: workerData,
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to update worker profile'));
    }
  }

  Future<bool> deleteLabour(int labourId) async {
    try {
      final response = await _dio.delete('${ApiConstants.labourLabours}/$labourId');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to delete worker'));
    }
  }

  Future<bool> bulkCreateLabours(List<Map<String, dynamic>> labours) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.labourLabours}/bulk',
        data: {'labours': labours},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to bulk import workers'));
    }
  }

  Future<List<ParsedLabourRow>> parseBulkLabours({
    required Uint8List fileBytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: filename),
      });

      final response = await _dio.post(
        '${ApiConstants.labourLabours}/bulk/parse',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['parsed'] as List? ?? [];
        return list.map((item) => ParsedLabourRow.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to parse Excel/CSV file'));
    }
  }

  Future<Uint8List> downloadBulkTemplate() async {
    try {
      final response = await _dio.get<List<int>>(
        '${ApiConstants.labourLabours}/bulk/template',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null) {
        return Uint8List.fromList(response.data!);
      }
      throw Exception('Empty template returned');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to download bulk upload template'));
    }
  }

  Future<bool> bulkTransferLabours({
    required dynamic sourceSiteId, // 'All' or int
    required int destinationSiteId,
    required List<int> labourIds,
    String roleFilter = 'All',
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.labourLabours}/bulk-transfer',
        data: {
          'source_site_id': sourceSiteId,
          'destination_site_id': destinationSiteId,
          'labour_ids': labourIds,
          'role_filter': roleFilter,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to execute bulk worker transfer'));
    }
  }

  Future<LabourWorkHistoryResult> getLabourWorkHistory(int labourId) async {
    try {
      final response = await _dio.get('${ApiConstants.labourLabours}/$labourId/history');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return LabourWorkHistoryResult.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw Exception('Failed to fetch worker history');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to load worker history and payout timeline'));
    }
  }

  // ==========================================
  // 3. DAILY ATTENDANCE ROSTER
  // ==========================================

  Future<List<LabourAttendanceItem>> getSiteAttendance(int siteId, String dateStr) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourAttendance,
        queryParameters: {
          'site_id': siteId,
          'date': dateStr,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final rawRoster = response.data['roster'];
        if (rawRoster is List) {
          return rawRoster
              .map((item) => LabourAttendanceItem.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch attendance checklist'));
    }
  }

  Future<bool> saveSiteAttendance(int siteId, String dateStr, List<Map<String, dynamic>> roster) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourAttendance,
        data: {
          'site_id': siteId,
          'date': dateStr,
          'roster': roster,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to save attendance checklist'));
    }
  }

  // ==========================================
  // 4. MONTHLY GRID ATTENDANCE
  // ==========================================

  Future<LabourMonthlyGridResult> getMonthlyGridAttendance({
    required int siteId,
    required String monthStr, // 'YYYY-MM'
    bool showAllSites = false,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourAttendanceMonthlySummary,
        queryParameters: {
          'site_id': siteId,
          'month': monthStr,
          'show_all_sites': showAllSites,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final rawList = response.data['grid'] as List? ?? [];
        final grid = rawList
            .map((item) => LabourMonthlyRow.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        LabourMonthDetails? details;
        if (response.data['monthDetails'] != null && response.data['monthDetails'] is Map) {
          details = LabourMonthDetails.fromJson(Map<String, dynamic>.from(response.data['monthDetails']));
        }

        return LabourMonthlyGridResult(grid: grid, monthDetails: details);
      }
      return LabourMonthlyGridResult(grid: []);
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch monthly attendance grid'));
    }
  }

  // ==========================================
  // 5. FINANCES, ADVANCES & PAYOUTS
  // ==========================================

  Future<LabourFinancesResult> getFinancesSummary({
    int? siteId,
    String? monthStr,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (siteId != null) 'site_id': siteId,
        if (monthStr != null && monthStr.isNotEmpty) 'month': monthStr,
      };

      final response = await _dio.get(
        ApiConstants.labourFinancesSummary,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final rawList = response.data['summary'] as List? ?? [];
        final summary = rawList
            .map((item) => LabourPayoutSummary.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        LabourMonthDetails? details;
        if (response.data['monthDetails'] != null && response.data['monthDetails'] is Map) {
          details = LabourMonthDetails.fromJson(Map<String, dynamic>.from(response.data['monthDetails']));
        }

        return LabourFinancesResult(summary: summary, monthDetails: details);
      }
      return LabourFinancesResult(summary: []);
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch finances & salary credit summary'));
    }
  }

  Future<bool> logAdvance({
    required int labourId,
    int? siteId,
    required double amount,
    required String date,
    String notes = '',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourFinancesAdvance,
        data: {
          'labour_id': labourId,
          'site_id': siteId,
          'amount': amount,
          'date': date,
          'notes': notes,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to log salary advance'));
    }
  }

  Future<bool> logPayout({
    required int labourId,
    int? siteId,
    required double amount,
    required String date,
    String paymentMode = 'Cash',
    String notes = '',
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourFinancesPayout,
        data: {
          'labour_id': labourId,
          'site_id': siteId,
          'amount': amount,
          'date': date,
          'payment_mode': paymentMode,
          'notes': notes,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to process worker payout'));
    }
  }

  // ==========================================
  // 6. DAILY SCHEDULE PLANNER
  // ==========================================

  Future<List<int>> getLabourSchedule({
    required int labourId,
    required String date,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourSchedule,
        queryParameters: {
          'labour_id': labourId,
          'date': date,
        },
      );
      if (response.statusCode == 200 && response.data['success'] == true) {
        final siteIds = response.data['site_ids'] as List? ?? [];
        return siteIds.map((id) => int.tryParse(id.toString()) ?? 0).where((id) => id > 0).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch daily schedule'));
    }
  }

  Future<bool> saveLabourSchedule({
    required int labourId,
    required String date,
    required List<int> siteIds,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.labourSchedule,
        data: {
          'labour_id': labourId,
          'date': date,
          'site_ids': siteIds,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to save daily schedule'));
    }
  }

  // ==========================================
  // 7. WAGE REVISION HISTORY
  // ==========================================

  Future<LabourWageHistoryResponse> getLabourWageHistory(int labourId) async {
    try {
      final response = await _dio.get('/labour/labours/$labourId/wage-history');
      if (response.statusCode == 200 && response.data != null) {
        return LabourWageHistoryResponse.fromJson(Map<String, dynamic>.from(response.data));
      }
      throw Exception('Failed to load wage history');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to load wage history'));
    }
  }

  Future<bool> addLabourWageRevision(
    int labourId, {
    required String effectiveDate,
    required double dailyWage,
    required double overtimePayPerHour,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/labour/labours/$labourId/wage-history',
        data: {
          'effective_date': effectiveDate,
          'daily_wage': dailyWage,
          'overtime_pay_per_hour': overtimePayPerHour,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to add wage revision'));
    }
  }

  Future<bool> updateLabourWageRevision(
    int revisionId, {
    required String effectiveDate,
    required double dailyWage,
    required double overtimePayPerHour,
    String? notes,
  }) async {
    try {
      final response = await _dio.put(
        '/labour/wage-history/$revisionId',
        data: {
          'effective_date': effectiveDate,
          'daily_wage': dailyWage,
          'overtime_pay_per_hour': overtimePayPerHour,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to update wage revision'));
    }
  }

  Future<bool> deleteLabourWageRevision(int revisionId) async {
    try {
      final response = await _dio.delete('/labour/wage-history/$revisionId');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to delete wage revision'));
    }
  }

  // ==========================================
  // 8. ADVANCED FINANCIAL LEDGER & EXPORTS
  // ==========================================

  Future<Map<String, dynamic>> getDetailedMonthlyLedger(int siteId, String month, {String? tillDate}) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourFinancesLedger,
        queryParameters: {
          'site_id': siteId,
          'month': month,
          if (tillDate != null) 'till_date': tillDate,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
      return {};
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to load detailed monthly ledger'));
    }
  }

  Future<List<LabourAdvanceRecord>> getLabourAdvances(int labourId, {String? month, int? siteId}) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourFinancesAdvances,
        queryParameters: {
          'labour_id': labourId,
          if (month != null) 'month': month,
          if (siteId != null) 'site_id': siteId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data['advances'] as List? ?? [];
        return list.map((item) => LabourAdvanceRecord.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to fetch labour advances'));
    }
  }

  Future<bool> deleteLabourAdvance(int advanceId) async {
    try {
      final response = await _dio.delete('${ApiConstants.labourFinancesAdvance}/$advanceId');
      return response.statusCode == 200;
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to delete salary advance'));
    }
  }

  Future<Uint8List> exportMonthlyWageExcel(int siteId, String month) async {
    try {
      final response = await _dio.get(
        ApiConstants.labourFinancesExport,
        queryParameters: {
          'site_id': siteId,
          'month': month,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data);
      }
      throw Exception('Failed to download Excel report');
    } catch (e) {
      throw Exception(_formatErrorMessage(e, 'Failed to export monthly wage Excel'));
    }
  }
}
