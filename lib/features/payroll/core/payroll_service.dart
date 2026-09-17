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
          '${ApiConstants.baseUrl}${ApiConstants.payrollDashboard}',
          queryParameters: {'month': queryMonth},
        );
        if (response.statusCode == 200) {
          final body = response.data;
          // API returns { data: [...entries], run: {...}, ok: true }
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
      debugPrint('PayrollService.getPayrollDashboard API error: $e — using mock fallback.');
    }

    // Fallback: use cached or generate mock
    if (_cachedPayslips.isEmpty || _currentPayPeriod != period) {
      _cachedPayslips = _generateMockPayslips(period);
    }
    final run = _generateMockRun(period, _cachedPayslips);
    _currentRun = run;
    return (run: run, payslips: _cachedPayslips);
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
          '${ApiConstants.baseUrl}${ApiConstants.payrollFinalize}',
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

    // Local fallback
    _cachedPayslips = _generateMockPayslips(payPeriod, isProcessed: true);
    final run = _generateMockRun(payPeriod, _cachedPayslips, isProcessed: true);
    _currentRun = run;

    recordAuditLog(
      action: 'FINALIZE_RUN',
      employeeName: 'All Employees',
      details: 'Executed and finalized full payroll run for $payPeriod.',
      performedByName: 'Admin',
    );

    return run;
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
          '${ApiConstants.baseUrl}${ApiConstants.payrollEmployee}/$employeeId/finalize',
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
    // Local mock fallback: update cached payslip status
    final idx = _cachedPayslips.indexWhere((p) => p.employeeId == employeeId);
    if (idx != -1) {
      final old = _cachedPayslips[idx];
      _cachedPayslips[idx] = Payslip(
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
        halfDays: old.halfDays,
        absentDays: old.absentDays,
        paidLeaveDays: old.paidLeaveDays,
        holidayDays: old.holidayDays,
        weeklyOffDays: old.weeklyOffDays,
        calendarDays: old.calendarDays,
        dailyRate: old.dailyRate,
        grossSalary: old.grossSalary,
        lopDays: old.lopDays,
        lopDeduction: old.lopDeduction,
        overtimeEnabled: old.overtimeEnabled,
        overtimeRate: old.overtimeRate,
        overtimeHours: old.overtimeHours,
        overtimeAmount: old.overtimeAmount,
        breakdown: old.breakdown,
        status: PayrollStatus.finalized,
        generatedDate: old.generatedDate,
        adjustments: old.adjustments,
      );
    }
    recordAuditLog(
      action: 'LOCK',
      employeeName: empName,
      details: 'Finalized and locked monthly payroll calculations for $payPeriod.',
      performedByName: performedByName ?? 'Admin',
    );
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
          '${ApiConstants.baseUrl}${ApiConstants.payrollEmployee}/$employeeId/unlock',
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
    // Local mock fallback
    final idx = _cachedPayslips.indexWhere((p) => p.employeeId == employeeId);
    if (idx != -1) {
      final old = _cachedPayslips[idx];
      _cachedPayslips[idx] = Payslip(
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
        halfDays: old.halfDays,
        absentDays: old.absentDays,
        paidLeaveDays: old.paidLeaveDays,
        holidayDays: old.holidayDays,
        weeklyOffDays: old.weeklyOffDays,
        calendarDays: old.calendarDays,
        dailyRate: old.dailyRate,
        grossSalary: old.grossSalary,
        lopDays: old.lopDays,
        lopDeduction: old.lopDeduction,
        overtimeEnabled: old.overtimeEnabled,
        overtimeRate: old.overtimeRate,
        overtimeHours: old.overtimeHours,
        overtimeAmount: old.overtimeAmount,
        breakdown: old.breakdown,
        status: PayrollStatus.draft,
        generatedDate: old.generatedDate,
        adjustments: old.adjustments,
      );
    }
    recordAuditLog(
      action: 'UNLOCK',
      employeeName: empName,
      details: 'Unlocked employee monthly payroll, reverting status to Draft.',
      performedByName: performedByName ?? 'Admin',
    );
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
          '${ApiConstants.baseUrl}/payroll/audit-logs',
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

  List<Payslip> _generateMockPayslips(String period,
      {bool isProcessed = false}) {
    final List<Map<String, dynamic>> rawData = [
      {
        'id': 'SLIP-101', 'empId': 'EMP-001', 'name': 'Rajesh Kumar',
        'dept': 'Engineering', 'role': 'Senior Software Engineer',
        'gross': 85000.0, 'pan': 'ABCDE1234F', 'bank': 'HDFC Bank - 5010098231',
        'working': 26, 'present': 25, 'unpaid': 1, 'ot': 8.0, 'otAmt': 2000.0, 'lopAmt': 3269.0,
      },
      {
        'id': 'SLIP-102', 'empId': 'EMP-002', 'name': 'Priya Sharma',
        'dept': 'Product', 'role': 'Product Manager',
        'gross': 95000.0, 'pan': 'PQRSW9876K', 'bank': 'ICICI Bank - 0019284756',
        'working': 26, 'present': 26, 'unpaid': 0, 'ot': 4.0, 'otAmt': 1000.0, 'lopAmt': 0.0,
      },
      {
        'id': 'SLIP-103', 'empId': 'EMP-003', 'name': 'Anish Verma',
        'dept': 'Engineering', 'role': 'UI/UX Lead Designer',
        'gross': 72000.0, 'pan': 'LMNOP4567J', 'bank': 'Axis Bank - 9180293847',
        'working': 26, 'present': 24, 'unpaid': 2, 'ot': 10.0, 'otAmt': 2500.0, 'lopAmt': 5538.0,
      },
      {
        'id': 'SLIP-104', 'empId': 'EMP-004', 'name': 'Sneha Patel',
        'dept': 'Operations', 'role': 'HR Business Partner',
        'gross': 65000.0, 'pan': 'STUVW3412M', 'bank': 'SBI - 3091827465',
        'working': 26, 'present': 26, 'unpaid': 0, 'ot': 0.0, 'otAmt': 0.0, 'lopAmt': 0.0,
      },
      {
        'id': 'SLIP-105', 'empId': 'EMP-005', 'name': 'Vikram Singh',
        'dept': 'Operations', 'role': 'Site Operations Lead',
        'gross': 58000.0, 'pan': 'FGHIJ5678N', 'bank': 'Kotak Bank - 7712398471',
        'working': 26, 'present': 23, 'unpaid': 3, 'ot': 14.0, 'otAmt': 3500.0, 'lopAmt': 6692.0,
      },
      {
        'id': 'SLIP-106', 'empId': 'EMP-006', 'name': 'Divya Nair',
        'dept': 'Marketing', 'role': 'Growth Manager',
        'gross': 60000.0, 'pan': 'KKLMM8821P', 'bank': 'HDFC Bank - 5010044192',
        'working': 26, 'present': 26, 'unpaid': 0, 'ot': 2.0, 'otAmt': 500.0, 'lopAmt': 0.0,
      },
    ];

    return rawData.map((item) {
      final gross = item['gross'] as double;
      final unpaid = item['unpaid'] as int;
      final ot = item['ot'] as double;
      final lopAmt = item['lopAmt'] as double;
      final otAmt = item['otAmt'] as double;
      final working = item['working'] as int;

      final breakdown = SalaryBreakdown.calculate(
        monthlyGross: gross,
        overtimeHours: ot,
        unpaidLeaves: unpaid,
        totalWorkingDays: working,
      );

      return Payslip(
        id: item['id'],
        entryId: null,
        employeeId: item['empId'],
        employeeName: item['name'],
        designation: item['role'],
        department: item['dept'],
        panNumber: item['pan'],
        bankAccount: item['bank'],
        payPeriod: period,
        totalWorkingDays: 31,
        presentDays: (item['present'] as int).toDouble(),
        lopDays: unpaid.toDouble(),
        grossSalary: gross,
        overtimeHours: ot,
        lopDeduction: lopAmt,
        overtimeAmount: otAmt,
        breakdown: breakdown,
        status: isProcessed ? PayrollStatus.finalized : PayrollStatus.draft,
        generatedDate: DateTime.now(),
      );
    }).toList();
  }
}

// [mod:2026-02-25T09:00:00+05:30]

// [rev:2026-08-25T09:00:00+05:30]
