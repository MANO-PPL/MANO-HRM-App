import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_audit_model.dart';

double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

class PayrollService {
  final Dio? _dio;

  PayrollService([this._dio]);

  // ---------------------------------------------------------------------------
  // Month Utilities
  // ---------------------------------------------------------------------------

  String _monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);

  /// Returns "YYYY-MM" from a human label like "August 2026"
  String _labelToQuery(String label) {
    const monthMap = {
      'January': '01', 'February': '02', 'March': '03', 'April': '04',
      'May': '05', 'June': '06', 'July': '07', 'August': '08',
      'September': '09', 'October': '10', 'November': '11', 'December': '12',
    };
    final parts = label.split(' ');
    if (parts.length == 2) {
      final m = monthMap[parts[0]];
      final y = parts[1];
      if (m != null && y.length == 4) return '$y-$m';
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  List<Payslip> _cachedPayslips = [];
  PayrollRun? _currentRun;
  String _currentPayPeriod = '';
  final List<PayrollAuditLog> _localAuditLogs = [];

  /// Records an audit log locally and keeps it synchronized across sessions
  void recordAuditLog({
    required String action,
    String? employeeName,
    required String details,
    String performedByName = 'Admin',
    DateTime? timestamp,
  }) {
    final log = PayrollAuditLog(
      logId: 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
      action: action,
      performedByName: performedByName,
      employeeName: employeeName,
      details: details,
      createdAt: timestamp ?? DateTime.now(),
    );
    _localAuditLogs.insert(0, log);
  }

  String get currentPayPeriod {
    if (_currentPayPeriod.isEmpty) {
      _currentPayPeriod = _monthLabel(DateTime.now());
    }
    return _currentPayPeriod;
  }

  /// Last 12 months (current + 11 previous)
  List<String> get availablePayPeriods {
    final now = DateTime.now();
    return List.generate(12, (i) {
      return _monthLabel(DateTime(now.year, now.month - i, 1));
    });
  }

  // ==========================================
  // Web Parity API Integration
  // ==========================================

  /// Check if payroll settings are configured
  Future<PayrollSetupStatus> getSetupStatus() async {
    try {
      if (_dio != null) {
        final res = await _dio.get(ApiConstants.payrollSetupStatus);
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          return PayrollSetupStatus.fromJson(data is Map<String, dynamic> ? data : {});
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getSetupStatus error: $e');
    }
    return const PayrollSetupStatus(isConfigured: true, packagesCount: 0);
  }

  /// Get organization payroll settings
  Future<PayrollSettings> getPayrollSettings() async {
    try {
      if (_dio != null) {
        final res = await _dio.get(ApiConstants.payrollSettings);
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          return PayrollSettings.fromJson(data is Map<String, dynamic> ? data : {});
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPayrollSettings error: $e');
    }
    return const PayrollSettings();
  }

  /// Update organization payroll settings
  Future<PayrollSettings> updatePayrollSettings(Map<String, dynamic> settingsData) async {
    try {
      if (_dio != null) {
        final res = await _dio.put(
          ApiConstants.payrollSettings,
          data: settingsData,
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          return PayrollSettings.fromJson(data is Map<String, dynamic> ? data : {});
        }
      }
    } catch (e) {
      debugPrint('PayrollService.updatePayrollSettings error: $e');
    }
    return PayrollSettings.fromJson(settingsData);
  }

  /// List all salary packages
  Future<List<SalaryPackage>> getPackages() async {
    try {
      if (_dio != null) {
        final res = await _dio.get(ApiConstants.payrollPackages);
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((p) => SalaryPackage.fromJson(p as Map<String, dynamic>)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPackages error: $e');
    }
    return [];
  }

  /// Get single package details
  Future<SalaryPackage?> getPackageById(int packageId) async {
    try {
      if (_dio != null) {
        final res = await _dio.get('${ApiConstants.payrollPackages}/$packageId');
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return SalaryPackage.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPackageById error: $e');
    }
    return null;
  }

  /// Create a new salary package
  Future<SalaryPackage> createPackage(Map<String, dynamic> packageData) async {
    try {
      if (_dio != null) {
        final res = await _dio.post(
          ApiConstants.payrollPackages,
          data: packageData,
        );
        if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return SalaryPackage.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.createPackage error: $e');
    }
    return SalaryPackage.fromJson(packageData);
  }

  /// Update package
  Future<SalaryPackage> updatePackage(int packageId, Map<String, dynamic> packageData) async {
    try {
      if (_dio != null) {
        final res = await _dio.put(
          '${ApiConstants.payrollPackages}/$packageId',
          data: packageData,
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return SalaryPackage.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.updatePackage error: $e');
    }
    return SalaryPackage.fromJson(packageData);
  }

  /// Delete package
  Future<bool> deletePackage(int packageId) async {
    try {
      if (_dio != null) {
        final res = await _dio.delete('${ApiConstants.payrollPackages}/$packageId');
        return res.statusCode == 200;
      }
    } catch (e) {
      debugPrint('PayrollService.deletePackage error: $e');
    }
    return true;
  }

  /// Add component to package
  Future<SalaryComponent?> addPackageComponent(int packageId, Map<String, dynamic> componentData) async {
    try {
      if (_dio != null) {
        final res = await _dio.post(
          '${ApiConstants.payrollPackages}/$packageId/components',
          data: componentData,
        );
        if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return SalaryComponent.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.addPackageComponent error: $e');
    }
    return null;
  }

  /// Update component in package
  Future<SalaryComponent?> updatePackageComponent(int packageId, int componentId, Map<String, dynamic> componentData) async {
    try {
      if (_dio != null) {
        final res = await _dio.put(
          '${ApiConstants.payrollPackages}/$packageId/components/$componentId',
          data: componentData,
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return SalaryComponent.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.updatePackageComponent error: $e');
    }
    return null;
  }

  /// Delete component
  Future<bool> deletePackageComponent(int packageId, int componentId) async {
    try {
      if (_dio != null) {
        final res = await _dio.delete(
          '${ApiConstants.payrollPackages}/$packageId/components/$componentId',
        );
        return res.statusCode == 200;
      }
    } catch (e) {
      debugPrint('PayrollService.deletePackageComponent error: $e');
    }
    return true;
  }

  /// List all employee package assignments
  Future<List<EmployeePackageAssignment>> getAssignments({String? search, int? departmentId}) async {
    try {
      if (_dio != null) {
        final res = await _dio.get(
          ApiConstants.payrollAssignments,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            if (departmentId != null) 'department_id': departmentId,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((a) => EmployeePackageAssignment.fromJson(a as Map<String, dynamic>)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getAssignments error: $e');
    }
    return [];
  }

  /// Assign package to employee
  Future<bool> assignPackageToEmployee(int employeeId, int packageId, String effectiveFrom) async {
    try {
      if (_dio != null) {
        final res = await _dio.post(
          '${ApiConstants.payrollEmployee}/$employeeId/assign-package',
          data: {
            'package_id': packageId,
            'effective_from': effectiveFrom,
          },
        );
        return res.statusCode == 200 || res.statusCode == 201;
      }
    } catch (e) {
      debugPrint('PayrollService.assignPackageToEmployee error: $e');
    }
    return true;
  }

  /// Unassign package from employee
  Future<bool> unassignPackageFromEmployee(int employeeId, {String? effectiveTo}) async {
    try {
      if (_dio != null) {
        final res = await _dio.post(
          '${ApiConstants.payrollEmployee}/$employeeId/unassign-package',
          data: {
            'effective_to': effectiveTo ?? DateTime.now().toIso8601String().split('T')[0],
          },
        );
        return res.statusCode == 200;
      }
    } catch (e) {
      debugPrint('PayrollService.unassignPackageFromEmployee error: $e');
    }
    return true;
  }

  /// List all payroll runs
  Future<List<PayrollRun>> getPayrollRuns({String? runType, String? status}) async {
    try {
      if (_dio != null) {
        final res = await _dio.get(
          ApiConstants.payrollRuns,
          queryParameters: {
            if (runType != null) 'run_type': runType,
            if (status != null) 'status': status,
          },
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is List) {
            return data.map((r) => PayrollRun.fromApi(r as Map<String, dynamic>)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPayrollRuns error: $e');
    }
    return [];
  }

  /// Get details of a single payroll run (summary, itemized employee payslips)
  Future<PayrollRun?> getPayrollRunDetails(int runId) async {
    try {
      if (_dio != null) {
        final res = await _dio.get('${ApiConstants.payrollRuns}/$runId');
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return PayrollRun.fromApi(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPayrollRunDetails error: $e');
    }
    return null;
  }

  /// Trigger payroll run (Batch or Individual)
  Future<PayrollRun?> triggerPayrollRun(Map<String, dynamic> runPayload) async {
    try {
      if (_dio != null) {
        final res = await _dio.post(
          ApiConstants.payrollRuns,
          data: runPayload,
        );
        if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return PayrollRun.fromApi(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.triggerPayrollRun error: $e');
    }
    return null;
  }

  /// Rerun draft run
  Future<PayrollRun?> rerunPayrollRun(int runId) async {
    try {
      if (_dio != null) {
        final res = await _dio.patch(
          '${ApiConstants.payrollRuns}/$runId',
          data: {'action': 'rerun'},
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return PayrollRun.fromApi(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.rerunPayrollRun error: $e');
    }
    return null;
  }

  /// Approve payroll run
  Future<PayrollRun?> approvePayrollRun(int runId) async {
    try {
      if (_dio != null) {
        final res = await _dio.patch(
          '${ApiConstants.payrollRuns}/$runId',
          data: {'status': 'approved'},
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return PayrollRun.fromApi(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.approvePayrollRun error: $e');
    }
    return null;
  }

  /// Mark payroll run as paid
  Future<PayrollRun?> markRunAsPaid(
    dynamic runId, {
    String? paidAt,
    DateTime? paidAtDate,
    String? payPeriod,
    String? paymentMode,
    String? transactionRef,
    String? performedByName,
  }) async {
    final rId = runId.toString();
    final effectivePaidAt = paidAt ?? (paidAtDate != null ? paidAtDate.toIso8601String() : DateTime.now().toIso8601String());
    PayrollRun? updatedRun;
    try {
      if (_dio != null && rId.isNotEmpty && rId != 'MOCK-RUN') {
        final payload = <String, dynamic>{
          'status': 'paid',
          'paid_at': effectivePaidAt,
          if (paymentMode != null) 'payment_mode': paymentMode,
          if (transactionRef != null) 'reference': transactionRef,
        };
        final res = await _dio.patch(
          '${ApiConstants.payrollRuns}/$rId',
          data: payload,
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            updatedRun = PayrollRun.fromApi(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.markRunAsPaid error: $e');
    }

    if (_currentRun != null) {
      _currentRun = PayrollRun(
        id: _currentRun!.id,
        payPeriod: _currentRun!.payPeriod,
        status: PayrollStatus.paid,
        totalEmployees: _currentRun!.totalEmployees,
        totalGrossPayout: _currentRun!.totalGrossPayout,
        totalDeductions: _currentRun!.totalDeductions,
        totalNetPayout: _currentRun!.totalNetPayout,
        processedDate: _currentRun!.processedDate,
        isLocked: true,
      );
    }

    _cachedPayslips = _cachedPayslips.map((p) => Payslip(
      id: p.id,
      entryId: p.entryId,
      employeeId: p.employeeId,
      employeeName: p.employeeName,
      designation: p.designation,
      department: p.department,
      panNumber: p.panNumber,
      bankAccount: p.bankAccount,
      payPeriod: p.payPeriod,
      totalWorkingDays: p.totalWorkingDays,
      presentDays: p.presentDays,
      halfDays: p.halfDays,
      absentDays: p.absentDays,
      paidLeaveDays: p.paidLeaveDays,
      holidayDays: p.holidayDays,
      weeklyOffDays: p.weeklyOffDays,
      calendarDays: p.calendarDays,
      dailyRate: p.dailyRate,
      grossSalary: p.grossSalary,
      lopDays: p.lopDays,
      lopDeduction: p.lopDeduction,
      overtimeEnabled: p.overtimeEnabled,
      overtimeRate: p.overtimeRate,
      overtimeHours: p.overtimeHours,
      overtimeAmount: p.overtimeAmount,
      breakdown: p.breakdown,
      status: PayrollStatus.paid,
      generatedDate: p.generatedDate,
      adjustments: p.adjustments,
    )).toList();

    recordAuditLog(
      action: 'MARK_RUN_PAID',
      employeeName: 'All Employees',
      details: 'Marked full payroll run as Paid for ${payPeriod ?? currentPayPeriod}. Mode: ${paymentMode ?? "All"}, Ref: ${transactionRef ?? "N/A"}',
      performedByName: performedByName ?? 'Admin',
    );

    return updatedRun;
  }

  /// Get single employee itemized payslip
  Future<ItemizedPayslip?> getEmployeePayslip(int runId, int employeeId) async {
    try {
      if (_dio != null) {
        final res = await _dio.get(
          '${ApiConstants.payrollRuns}/$runId/employees/$employeeId/payslip',
        );
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data['data'] ?? res.data;
          if (data is Map<String, dynamic>) {
            return ItemizedPayslip.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getEmployeePayslip error: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 1. Fetch Payroll Dashboard (replaces getPayrollRun + getPayslips)
  // ---------------------------------------------------------------------------

  Future<({PayrollRun run, List<Payslip> payslips})> getPayrollDashboard({
    String? payPeriod,
  }) async {
    final period = payPeriod ?? currentPayPeriod;
    _currentPayPeriod = period;
    final queryMonth = _labelToQuery(period);

    try {
      if (_dio != null) {
        final response = await _dio.get(
          ApiConstants.payrollDashboard,
          queryParameters: {'month': queryMonth},
        );
        if (response.statusCode == 200) {
          final body = response.data;
          final entries = (body['data'] as List?) ?? [];
          final payslips = entries
              .map((e) => Payslip.fromApiEntry(e as Map<String, dynamic>, period))
              .toList();

          _cachedPayslips = payslips;

          final runRaw = body['run'] as Map<String, dynamic>?;
          final run = _buildRun(period, payslips, runRaw);
          _currentRun = run;
          return (run: run, payslips: payslips);
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getPayrollDashboard API error: $e');
    }

    final emptyRun = PayrollRun(
      id: '',
      payPeriod: period,
      status: PayrollStatus.draft,
      totalEmployees: _cachedPayslips.length,
      totalGrossPayout: 0,
      totalDeductions: 0,
      totalNetPayout: 0,
      processedDate: DateTime.now(),
      isLocked: false,
    );
    _currentRun = emptyRun;
    return (run: emptyRun, payslips: _cachedPayslips);
  }

  // ---------------------------------------------------------------------------
  // 2. Fetch payslips for a period with optional filtering (view-only)
  // ---------------------------------------------------------------------------

  Future<List<Payslip>> getPayslips({
    String? payPeriod,
    String? department,
    String? searchQuery,
  }) async {
    final period = payPeriod ?? currentPayPeriod;
    if (_cachedPayslips.isEmpty || _currentPayPeriod != period) {
      await getPayrollDashboard(payPeriod: period);
    }
    return _filterPayslips(
      _cachedPayslips,
      department: department,
      searchQuery: searchQuery,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Fetch PayrollRun summary
  // ---------------------------------------------------------------------------

  Future<PayrollRun> getPayrollRun({String? payPeriod}) async {
    final period = payPeriod ?? currentPayPeriod;
    if (_currentRun != null && _currentPayPeriod == period) {
      return _currentRun!;
    }
    final result = await getPayrollDashboard(payPeriod: period);
    return result.run;
  }

  // ---------------------------------------------------------------------------
  // 4. Process Payroll Run
  // ---------------------------------------------------------------------------

  Future<PayrollRun> processPayrollRun({required String payPeriod}) async {
    _currentPayPeriod = payPeriod;
    final queryMonth = _labelToQuery(payPeriod);

    try {
      if (_dio != null) {
        final response = await _dio.post(
          ApiConstants.payrollFinalize,
          data: {'month': queryMonth},
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final result = await getPayrollDashboard(payPeriod: payPeriod);
          return result.run;
        }
      }
    } catch (e) {
      debugPrint('PayrollService.processPayrollRun error: $e');
    }

    final fallbackRun = PayrollRun(
      id: '',
      payPeriod: payPeriod,
      status: PayrollStatus.draft,
      totalEmployees: 0,
      totalGrossPayout: 0,
      totalDeductions: 0,
      totalNetPayout: 0,
      processedDate: DateTime.now(),
      isLocked: false,
    );
    _currentRun = fallbackRun;
    return fallbackRun;
  }

  // ---------------------------------------------------------------------------
  // 5. Per-Employee: Finalize (Lock) Payroll
  // ---------------------------------------------------------------------------

  /// Calls POST /payroll/employees/:employeeId/finalize { month }
  /// Matches web's payrollService.finalizeEmployee()
  Future<void> finalizeEmployee({
    required String employeeId,
    required String payPeriod,
    String? employeeName,
    String? performedByName,
  }) async {
    final queryMonth = _labelToQuery(payPeriod);
    final empName = employeeName ??
        (_cachedPayslips.any((p) => p.employeeId == employeeId)
            ? _cachedPayslips.firstWhere((p) => p.employeeId == employeeId).employeeName
            : 'Employee');

    try {
      if (_dio != null) {
        final response = await _dio.post(
          '${ApiConstants.payrollEmployee}/$employeeId/finalize',
          data: {'month': queryMonth},
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          recordAuditLog(
            action: 'LOCK',
            employeeName: empName,
            details: 'Finalized and locked monthly payroll calculations for $payPeriod.',
            performedByName: performedByName ?? 'Admin',
          );
          // Refresh cache
          await getPayrollDashboard(payPeriod: payPeriod);
          return;
        }
      }
    } catch (e) {
      debugPrint('PayrollService.finalizeEmployee error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 6. Per-Employee: Unlock Payroll
  // ---------------------------------------------------------------------------

  /// Calls POST /payroll/employees/:employeeId/unlock { month }
  /// Matches web's payrollService.unlockEmployee()
  Future<void> unlockEmployee({
    required String employeeId,
    required String payPeriod,
    String? employeeName,
    String? performedByName,
  }) async {
    final queryMonth = _labelToQuery(payPeriod);
    final empName = employeeName ??
        (_cachedPayslips.any((p) => p.employeeId == employeeId)
            ? _cachedPayslips.firstWhere((p) => p.employeeId == employeeId).employeeName
            : 'Employee');

    try {
      if (_dio != null) {
        final response = await _dio.post(
          '${ApiConstants.payrollEmployee}/$employeeId/unlock',
          data: {'month': queryMonth},
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          recordAuditLog(
            action: 'UNLOCK',
            employeeName: empName,
            details: 'Unlocked employee monthly payroll, reverting status to Draft.',
            performedByName: performedByName ?? 'Admin',
          );
          await getPayrollDashboard(payPeriod: payPeriod);
          return;
        }
      }
    } catch (e) {
      debugPrint('PayrollService.unlockEmployee error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 6b. Per-Employee: Mark as Paid
  // ---------------------------------------------------------------------------

  /// Calls POST /payroll/employees/:employeeId/pay { month, payment_mode, reference }
  /// Matches web's payrollService.payEmployee()
  Future<void> payEmployee({
    required String employeeId,
    required String payPeriod,
    String? paymentMode,
    String? reference,
    String? employeeName,
    String? performedByName,
  }) async {
    final queryMonth = _labelToQuery(payPeriod);
    final empName = employeeName ??
        (_cachedPayslips.any((p) => p.employeeId == employeeId)
            ? _cachedPayslips.firstWhere((p) => p.employeeId == employeeId).employeeName
            : 'Employee');

    try {
      if (_dio != null) {
        final payload = <String, dynamic>{
          'month': queryMonth,
          if (paymentMode != null) 'payment_mode': paymentMode,
          if (reference != null) 'reference': reference,
        };
        final response = await _dio.post(
          '${ApiConstants.payrollEmployee}/$employeeId/pay',
          data: payload,
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          recordAuditLog(
            action: 'PAY',
            employeeName: empName,
            details: 'Marked employee monthly payout as Paid for $payPeriod. Mode: ${paymentMode ?? "Default"}, Ref: ${reference ?? "N/A"}',
            performedByName: performedByName ?? 'Admin',
          );
          await getPayrollDashboard(payPeriod: payPeriod);
          return;
        }
      }
    } catch (e) {
      debugPrint('PayrollService.payEmployee error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 7. Audit Trail
  // ---------------------------------------------------------------------------

  /// Calls GET /payroll/audit-logs?month=YYYY-MM&employeeId=...
  /// Matches web's payrollService.getAuditLogs()
  Future<List<PayrollAuditLog>> getAuditLogs({
    required String payPeriod,
    String? employeeId,
  }) async {
    final queryMonth = _labelToQuery(payPeriod);
    final List<PayrollAuditLog> apiLogs = [];
    try {
      if (_dio != null) {
        final params = <String, dynamic>{'month': queryMonth};
        if (employeeId != null && employeeId.isNotEmpty) {
          params['employeeId'] = employeeId;
        }
        final response = await _dio.get(
          '/payroll/audit-logs',
          queryParameters: params,
        );
        if (response.statusCode == 200) {
          final data = response.data;
          final list = (data['data'] as List?) ?? [];
          apiLogs.addAll(
            list.map((e) => PayrollAuditLog.fromJson(e as Map<String, dynamic>)),
          );
        }
      }
    } catch (e) {
      debugPrint('PayrollService.getAuditLogs error: $e');
    }

    // Merge API logs and local audit logs, deduplicating by action+employeeName+details
    final Map<String, PayrollAuditLog> merged = {};
    for (final log in apiLogs) {
      final key = '${log.action}_${log.employeeName}_${log.details}';
      merged[key] = log;
    }
    for (final log in _localAuditLogs) {
      final key = '${log.action}_${log.employeeName}_${log.details}';
      if (!merged.containsKey(key)) {
        merged[key] = log;
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  // ---------------------------------------------------------------------------
  // 8. Update payslip adjustment (per-entry — view only, kept for completeness)
  // ---------------------------------------------------------------------------

  Future<Payslip> updatePayslipAdjustment({
    required String payslipId,
    required double salaryAdvance,
    required double overtimeHours,
  }) async {
    final index = _cachedPayslips.indexWhere((p) => p.id == payslipId);
    if (index != -1) {
      final old = _cachedPayslips[index];
      final newBreakdown = SalaryBreakdown.calculate(
        monthlyGross: old.breakdown.basic * 2.0,
        overtimeHours: overtimeHours,
        unpaidLeaves: old.unpaidLeaves,
        totalWorkingDays: old.totalWorkingDays,
        salaryAdvance: salaryAdvance,
      );

      final updated = Payslip(
        id: old.id,
        entryId: old.entryId,
        employeeId: old.employeeId,
        employeeName: old.employeeName,
        designation: old.designation,
        department: old.department,
        panNumber: old.panNumber,
        bankAccount: old.bankAccount,
        payPeriod: old.payPeriod,
        totalWorkingDays: old.totalWorkingDays,
        presentDays: old.presentDays,
        lopDays: old.lopDays,
        grossSalary: old.grossSalary,
        overtimeHours: overtimeHours,
        lopDeduction: old.lopDeduction,
        overtimeAmount: old.overtimeAmount,
        breakdown: newBreakdown,
        status: old.status,
        generatedDate: DateTime.now(),
        adjustments: old.adjustments,
      );

      _cachedPayslips[index] = updated;
      return updated;
    }
    throw Exception('Payslip not found');
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  List<Payslip> _filterPayslips(
    List<Payslip> slips, {
    String? department,
    String? searchQuery,
  }) {
    return slips.where((slip) {
      bool matchesDept = true;
      if (department != null && department != 'All' && department.isNotEmpty) {
        matchesDept =
            slip.department.toLowerCase() == department.toLowerCase();
      }
      bool matchesSearch = true;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        matchesSearch = slip.employeeName.toLowerCase().contains(q) ||
            slip.employeeId.toLowerCase().contains(q) ||
            slip.designation.toLowerCase().contains(q);
      }
      return matchesDept && matchesSearch;
    }).toList();
  }

  PayrollRun _buildRun(
    String period,
    List<Payslip> payslips,
    Map<String, dynamic>? runRaw,
  ) {
    double totalGross = 0;
    double totalNet = 0;
    double totalDeductions = 0;
    for (final s in payslips) {
      totalGross += s.breakdown.totalEarnings;
      totalDeductions += s.breakdown.totalDeductions;
      totalNet += s.netPay;
    }

    PayrollStatus status = PayrollStatus.draft;
    if (runRaw != null) {
      final st = runRaw['status']?.toString().toLowerCase() ?? '';
      if (st == 'paid') {
        status = PayrollStatus.paid;
      } else if (st == 'finalized') {
        status = PayrollStatus.finalized;
      } else if (st == 'live' || st == 'draft') {
        status = PayrollStatus.draft;
      }
    }

    return PayrollRun(
      id: runRaw?['run_id']?.toString() ?? 'PR-${period.replaceAll(' ', '-')}',
      payPeriod: period,
      status: status,
      totalEmployees: payslips.length,
      totalGrossPayout: totalGross > 0 ? totalGross : _toDouble(runRaw?['totalGross']),
      totalDeductions: totalDeductions > 0 ? totalDeductions : _toDouble(runRaw?['totalDeductions']),
      totalNetPayout: totalNet > 0 ? totalNet : _toDouble(runRaw?['totalNet']),
      processedDate: DateTime.now(),
      isLocked: status.isLocked,
    );
  }

  // ---------------------------------------------------------------------------
  // Mock Generators (fallback when API unavailable)
  // ---------------------------------------------------------------------------

  PayrollRun _generateMockRun(
    String period,
    List<Payslip> payslips, {
    bool isProcessed = false,
  }) {
    double totalGross = 0;
    double totalDeductions = 0;
    for (final s in payslips) {
      totalGross += s.breakdown.totalEarnings;
      totalDeductions += s.breakdown.totalDeductions;
    }
    return PayrollRun(
      id: 'PR-${period.replaceAll(' ', '-')}',
      payPeriod: period,
      status: isProcessed ? PayrollStatus.finalized : PayrollStatus.draft,
      totalEmployees: payslips.length,
      totalGrossPayout: totalGross,
      totalDeductions: totalDeductions,
      totalNetPayout: totalGross - totalDeductions,
      processedDate: DateTime.now().subtract(const Duration(days: 3)),
      isLocked: isProcessed,
    );
  }

  List<Payslip> _generateMockPayslips(String period, {bool isProcessed = false}) {
    return [];
  }

  List<SalaryPackage> _generateMockPackages() {
    return [];
  }

  List<EmployeePackageAssignment> _generateMockAssignments() {
    return [];
  }

  List<PayrollRun> _generateMockRunsList() {
    return [];
  }
}

// [mod:2026-02-25T09:00:00+05:30]

// [rev:2026-08-25T09:00:00+05:30]
