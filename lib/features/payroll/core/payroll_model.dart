import 'package:intl/intl.dart';

double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic val, [int defaultValue = 0]) {
  if (val == null) return defaultValue;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? defaultValue);
  return defaultValue;
}

enum PayrollStatus {
  draft,
  processing,
  finalized,
  paid,
  approved,
  disbursed,
}

extension PayrollStatusExtension on PayrollStatus {
  String get label {
    switch (this) {
      case PayrollStatus.draft:
        return 'Draft';
      case PayrollStatus.processing:
        return 'Processing';
      case PayrollStatus.finalized:
        return 'Finalized';
      case PayrollStatus.paid:
        return 'Paid';
      case PayrollStatus.approved:
        return 'Approved';
      case PayrollStatus.disbursed:
        return 'Disbursed';
    }
  }

  bool get isLocked =>
      this == PayrollStatus.finalized ||
      this == PayrollStatus.paid ||
      this == PayrollStatus.disbursed;
}

/// A single manual adjustment (bonus or deduction) on a payslip
class PayrollAdjustment {
  final String type; // 'addition' or 'deduction'
  final String label;
  final double amount;
  final String reason;

  const PayrollAdjustment({
    required this.type,
    required this.label,
    required this.amount,
    required this.reason,
  });

  factory PayrollAdjustment.fromJson(Map<String, dynamic> json) =>
      PayrollAdjustment(
        type: json['type']?.toString() ?? 'addition',
        label: json['label']?.toString() ?? '',
        amount: _toDouble(json['amount']),
        reason: json['reason']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'amount': amount,
        'reason': reason,
      };
}

class SalaryBreakdown {
  final dynamic _grossSalary;
  final dynamic _calendarDays;
  final dynamic _dailyRate;
  final dynamic _lopDays;
  final dynamic _lopDeduction;
  final bool overtimeEnabled;
  final dynamic _overtimeRate;
  final dynamic _overtimeHours;
  final dynamic _overtimeAmount;
  final dynamic _netSalary;

  const SalaryBreakdown({
    dynamic grossSalary = 0.0,
    dynamic calendarDays = 31,
    dynamic dailyRate = 0.0,
    dynamic lopDays = 0.0,
    dynamic lopDeduction = 0.0,
    this.overtimeEnabled = true,
    dynamic overtimeRate = 200.0,
    dynamic overtimeHours = 0.0,
    dynamic overtimeAmount = 0.0,
    dynamic netSalary = 0.0,
  })  : _grossSalary = grossSalary,
        _calendarDays = calendarDays,
        _dailyRate = dailyRate,
        _lopDays = lopDays,
        _lopDeduction = lopDeduction,
        _overtimeRate = overtimeRate,
        _overtimeHours = overtimeHours,
        _overtimeAmount = overtimeAmount,
        _netSalary = netSalary;

  int get calendarDays => _toInt(_calendarDays, 31);
  double get grossSalary => _toDouble(_grossSalary);
  double get dailyRate => _toDouble(_dailyRate);
  double get lopDays => _toDouble(_lopDays);
  double get lopDeduction => _toDouble(_lopDeduction);
  double get overtimeRate => _toDouble(_overtimeRate);
  double get overtimeHours => _toDouble(_overtimeHours);
  double get overtimeAmount => _toDouble(_overtimeAmount);
  double get netSalary => _toDouble(_netSalary);

  // Compatibility getters for legacy references
  double get basic => grossSalary;
  double get hra => 0.0;
  double get specialAllowance => 0.0;
  double get overtimePay => overtimeAmount;
  double get pf => 0.0;
  double get esi => 0.0;
  double get tds => 0.0;
  double get salaryAdvance => 0.0;
  double get leaveDeductions => lopDeduction;

  double get totalEarnings => grossSalary + overtimeAmount;
  double get totalDeductions => lopDeduction;

  factory SalaryBreakdown.calculate({
    required double monthlyGross,
    int calendarDays = 31,
    double lopDays = 0.0,
    bool overtimeEnabled = true,
    double overtimeRate = 200.0,
    double overtimeHours = 0.0,
    double salaryAdvance = 0.0,
    double overtimePay = 0.0,
    int unpaidLeaves = 0,
    int totalWorkingDays = 26,
    double tdsRate = 0.05,
  }) {
    final days = calendarDays > 0 ? calendarDays : 31;
    final effectiveLopDays = lopDays > 0 ? lopDays : unpaidLeaves.toDouble();
    final dRate = days > 0 ? (monthlyGross / days) : 0.0;
    final lDeduction = (effectiveLopDays * dRate);
    final otAmount = overtimePay > 0
        ? overtimePay
        : ((overtimeEnabled && overtimeHours > 0) ? (overtimeHours * overtimeRate) : 0.0);
    final net = monthlyGross - lDeduction + otAmount;

    return SalaryBreakdown(
      grossSalary: monthlyGross,
      calendarDays: days,
      dailyRate: dRate,
      lopDays: effectiveLopDays,
      lopDeduction: lDeduction,
      overtimeEnabled: overtimeEnabled,
      overtimeRate: overtimeRate,
      overtimeHours: overtimeHours,
      overtimeAmount: otAmount,
      netSalary: net,
    );
  }

  factory SalaryBreakdown.fromApiEntry({
    required double grossSalary,
    required double lopDeduction,
    required double overtimeAmount,
    required double pfAmount,
    required double netSalary,
    int calendarDays = 31,
    double lopDays = 0.0,
    bool overtimeEnabled = true,
    double overtimeRate = 200.0,
    double overtimeHours = 0.0,
    List<PayrollAdjustment> adjustments = const [],
  }) {
    final days = calendarDays > 0 ? calendarDays : 31;
    final dRate = days > 0 ? (grossSalary / days) : 0.0;
    final computedNet = netSalary > 0 ? netSalary : (grossSalary - lopDeduction + overtimeAmount);

    return SalaryBreakdown(
      grossSalary: grossSalary,
      calendarDays: days,
      dailyRate: dRate,
      lopDays: lopDays,
      lopDeduction: lopDeduction,
      overtimeEnabled: overtimeEnabled,
      overtimeRate: overtimeRate,
      overtimeHours: overtimeHours,
      overtimeAmount: overtimeAmount,
      netSalary: computedNet,
    );
  }

  Map<String, dynamic> toJson() => {
        'grossSalary': grossSalary,
        'calendarDays': calendarDays,
        'dailyRate': dailyRate,
        'lopDays': lopDays,
        'lopDeduction': lopDeduction,
        'overtimeEnabled': overtimeEnabled,
        'overtimeRate': overtimeRate,
        'overtimeHours': overtimeHours,
        'overtimeAmount': overtimeAmount,
        'netSalary': netSalary,
      };

  factory SalaryBreakdown.fromJson(Map<String, dynamic> json) {
    final gross = _toDouble(json['grossSalary'] ?? json['basic']);
    final days = _toInt(json['calendarDays'], 31);
    final dRate = _toDouble(json['dailyRate']);
    final lDays = _toDouble(json['lopDays'] ?? json['unpaidLeaves']);
    final lDeduction = _toDouble(json['lopDeduction'] ?? json['leaveDeductions']);
    final otHours = _toDouble(json['overtimeHours'] ?? json['overtimePay']);
    final otAmt = _toDouble(json['overtimeAmount'] ?? json['overtimePay']);
    final net = _toDouble(json['netSalary']);

    return SalaryBreakdown(
      grossSalary: gross,
      calendarDays: days > 0 ? days : 31,
      dailyRate: dRate > 0 ? dRate : (days > 0 ? gross / days : 0.0),
      lopDays: lDays,
      lopDeduction: lDeduction,
      overtimeEnabled: json['overtimeEnabled'] != false,
      overtimeRate: _toDouble(json['overtimeRate']),
      overtimeHours: otHours,
      overtimeAmount: otAmt,
      netSalary: net > 0 ? net : (gross - lDeduction + otAmt),
    );
  }
}

class Payslip {
  final String id;
  final String? entryId; // Backend payroll entry ID for API calls
  final String employeeId;
  final String employeeName;
  final String designation;
  final String department;
  final String panNumber;
  final String bankAccount;
  final String payPeriod; // e.g. "August 2026"
  final dynamic _totalWorkingDays;
  final dynamic _presentDays;
  final dynamic _halfDays;
  final dynamic _absentDays;
  final dynamic _paidLeaveDays;
  final dynamic _holidayDays;
  final dynamic _weeklyOffDays;
  final dynamic _calendarDays;
  final dynamic _dailyRate;
  final dynamic _grossSalary;
  final dynamic _lopDays;
  final dynamic _lopDeduction;
  final bool overtimeEnabled;
  final dynamic _overtimeRate;
  final dynamic _overtimeHours;
  final dynamic _overtimeAmount;
  final SalaryBreakdown breakdown;
  final PayrollStatus status;
  final DateTime generatedDate;
  final List<PayrollAdjustment> adjustments;

  Payslip({
    required this.id,
    this.entryId,
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.department,
    this.panNumber = 'ABCDE1234F',
    this.bankAccount = 'Bank Direct Deposit',
    required this.payPeriod,
    dynamic totalWorkingDays = 31,
    dynamic presentDays = 0.0,
    dynamic halfDays = 0.0,
    dynamic absentDays = 0.0,
    dynamic paidLeaveDays = 0.0,
    dynamic holidayDays = 0.0,
    dynamic weeklyOffDays = 0.0,
    dynamic calendarDays = 31,
    dynamic dailyRate = 0.0,
    dynamic grossSalary = 0.0,
    dynamic lopDays = 0.0,
    dynamic lopDeduction = 0.0,
    this.overtimeEnabled = true,
    dynamic overtimeRate = 200.0,
    dynamic overtimeHours = 0.0,
    dynamic overtimeAmount = 0.0,
    required this.breakdown,
    this.status = PayrollStatus.approved,
    DateTime? generatedDate,
    this.adjustments = const [],
  })  : _totalWorkingDays = totalWorkingDays,
        _presentDays = presentDays,
        _halfDays = halfDays,
        _absentDays = absentDays,
        _paidLeaveDays = paidLeaveDays,
        _holidayDays = holidayDays,
        _weeklyOffDays = weeklyOffDays,
        _calendarDays = calendarDays,
        _dailyRate = dailyRate,
        _grossSalary = grossSalary,
        _lopDays = lopDays,
        _lopDeduction = lopDeduction,
        _overtimeRate = overtimeRate,
        _overtimeHours = overtimeHours,
        _overtimeAmount = overtimeAmount,
        generatedDate = generatedDate ?? DateTime.now();

  int get totalWorkingDays => _toInt(_totalWorkingDays, 31);
  int get calendarDays => _toInt(_calendarDays, 31);
  double get presentDays => _toDouble(_presentDays);
  double get halfDays => _toDouble(_halfDays);
  double get absentDays => _toDouble(_absentDays);
  double get paidLeaveDays => _toDouble(_paidLeaveDays);
  double get holidayDays => _toDouble(_holidayDays);
  double get weeklyOffDays => _toDouble(_weeklyOffDays);
  double get dailyRate => _toDouble(_dailyRate);
  double get grossSalary => _toDouble(_grossSalary);
  double get lopDays => _toDouble(_lopDays);
  double get lopDeduction => _toDouble(_lopDeduction);
  double get overtimeRate => _toDouble(_overtimeRate);
  double get overtimeHours => _toDouble(_overtimeHours);
  double get overtimeAmount => _toDouble(_overtimeAmount);

  int get unpaidLeaves => lopDays.round();

  double get netPay => breakdown.netSalary;

  String get formattedNetPay =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(netPay);
  String get formattedGross =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(grossSalary);
  String get formattedDeductions =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(lopDeduction);
  String get formattedOvertimeAmount =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(overtimeAmount);
  String get formattedLopDeduction =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(lopDeduction);

  double get additionsTotal =>
      adjustments.where((a) => a.type == 'addition').fold(0.0, (s, a) => s + a.amount);
  double get deductionsTotal =>
      adjustments.where((a) => a.type == 'deduction').fold(0.0, (s, a) => s + a.amount);

  /// Construct from the real payroll dashboard API response entry
  factory Payslip.fromApiEntry(Map<String, dynamic> entry, String payPeriodStr) {
    final gross = _toDouble(entry['gross_salary'] ?? entry['gross_monthly_salary']);
    final net = _toDouble(entry['net_salary']);
    final lopDaysVal = _toDouble(entry['lop_days']);
    final lopDeductionVal = _toDouble(entry['lop_deduction']);
    final overtimeHoursVal = _toDouble(entry['overtime_hours']);
    final overtimeAmountVal = _toDouble(entry['overtime_amount']);

    // Parse adjustments
    List<PayrollAdjustment> adjustments = [];
    final adjRaw = entry['adjustments_json'];
    if (adjRaw != null) {
      final List<dynamic> adjList =
          adjRaw is String ? [] : (adjRaw is List ? adjRaw : []);
      adjustments = adjList
          .map((e) => PayrollAdjustment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse attendance snapshot
    Map<String, dynamic> attSnap = {};
    final attRaw = entry['attendance_snapshot_json'];
    if (attRaw is Map<String, dynamic>) attSnap = attRaw;

    final presentDays = _toDouble(attSnap['present_days']);
    final halfDays = _toDouble(attSnap['half_days']);
    final absentDays = _toDouble(attSnap['absent_days']);
    final paidLeaveDays = _toDouble(attSnap['paid_leave_days']);
    final holidayDays = _toDouble(attSnap['holiday_days']);
    final weeklyOffDays = _toDouble(attSnap['weekly_off_days']);

    // Salary snapshot
    Map<String, dynamic> salSnap = {};
    final salRaw = entry['salary_snapshot'];
    if (salRaw is Map<String, dynamic>) salSnap = salRaw;

    final otEnabled = salRaw != null
        ? (salSnap['overtime_enabled'] == 1 || salSnap['overtime_enabled'] == true)
        : (entry['employee_ot_enabled'] == 1 || entry['employee_ot_enabled'] == true);
    final otRate = _toDouble(salSnap['overtime_rate'] ?? entry['overtime_rate']);
    final calendarDays = _toInt(salSnap['calendar_days'] ?? entry['calendar_days'], 31);
    final dailyRate = calendarDays > 0 ? (gross / calendarDays) : 0.0;

    PayrollStatus status = PayrollStatus.draft;
    final statusStr = entry['status']?.toString().toLowerCase() ?? 'draft';
    if (statusStr == 'paid') {
      status = PayrollStatus.paid;
    } else if (statusStr == 'finalized') {
      status = PayrollStatus.finalized;
    } else if (statusStr == 'processing') {
      status = PayrollStatus.processing;
    }

    final breakdown = SalaryBreakdown.fromApiEntry(
      grossSalary: gross,
      lopDeduction: lopDeductionVal,
      overtimeAmount: overtimeAmountVal,
      pfAmount: 0.0,
      netSalary: net > 0 ? net : (gross - lopDeductionVal + overtimeAmountVal),
      calendarDays: calendarDays,
      lopDays: lopDaysVal,
      overtimeEnabled: otEnabled,
      overtimeRate: otRate,
      overtimeHours: overtimeHoursVal,
      adjustments: adjustments,
    );

    return Payslip(
      id: 'SLIP-${entry['employee_id'] ?? 'UNK'}',
      entryId: entry['entry_id']?.toString(),
      employeeId: entry['employee_id']?.toString() ?? '',
      employeeName: entry['user_name']?.toString() ?? entry['email']?.toString() ?? 'Employee',
      designation: entry['designation']?.toString() ?? 'Staff',
      department: entry['department']?.toString() ?? 'General',
      payPeriod: payPeriodStr,
      totalWorkingDays: calendarDays,
      presentDays: presentDays,
      halfDays: halfDays,
      absentDays: absentDays,
      paidLeaveDays: paidLeaveDays,
      holidayDays: holidayDays,
      weeklyOffDays: weeklyOffDays,
      calendarDays: calendarDays,
      dailyRate: dailyRate,
      grossSalary: gross,
      lopDays: lopDaysVal,
      lopDeduction: lopDeductionVal,
      overtimeEnabled: otEnabled,
      overtimeRate: otRate,
      overtimeHours: overtimeHoursVal,
      overtimeAmount: overtimeAmountVal,
      breakdown: breakdown,
      status: status,
      adjustments: adjustments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entryId': entryId,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'designation': designation,
        'department': department,
        'panNumber': panNumber,
        'bankAccount': bankAccount,
        'payPeriod': payPeriod,
        'totalWorkingDays': totalWorkingDays,
        'presentDays': presentDays,
        'unpaidLeaves': unpaidLeaves,
        'overtimeHours': overtimeHours,
        'lopDeduction': lopDeduction,
        'overtimeAmount': overtimeAmount,
        'breakdown': breakdown.toJson(),
        'status': status.name,
        'generatedDate': generatedDate.toIso8601String(),
        'adjustments': adjustments.map((a) => a.toJson()).toList(),
      };

  factory Payslip.fromJson(Map<String, dynamic> json) {
    final gross = _toDouble(json['grossSalary'] ?? json['gross_salary'] ?? (json['breakdown'] != null ? json['breakdown']['grossSalary'] : 0.0));
    final lopDays = _toDouble(json['lopDays'] ?? json['unpaidLeaves']);
    return Payslip(
      id: json['id'] ?? '',
      entryId: json['entryId']?.toString(),
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? 'Employee',
      designation: json['designation'] ?? 'Staff',
      department: json['department'] ?? 'General',
      panNumber: json['panNumber'] ?? 'ABCDE1234F',
      bankAccount: json['bankAccount'] ?? 'Bank Direct Deposit',
      payPeriod: json['payPeriod'] ?? '',
      totalWorkingDays: _toInt(json['totalWorkingDays'], 31),
      presentDays: _toDouble(json['presentDays']),
      lopDays: lopDays,
      grossSalary: gross,
      overtimeHours: _toDouble(json['overtimeHours']),
      lopDeduction: _toDouble(json['lopDeduction']),
      overtimeAmount: _toDouble(json['overtimeAmount']),
      breakdown: json['breakdown'] != null
          ? SalaryBreakdown.fromJson(json['breakdown'])
          : SalaryBreakdown.calculate(monthlyGross: gross > 0 ? gross : 45000, lopDays: lopDays),
      status: PayrollStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PayrollStatus.approved,
      ),
      generatedDate: json['generatedDate'] != null
          ? DateTime.tryParse(json['generatedDate']) ?? DateTime.now()
          : DateTime.now(),
      adjustments: json['adjustments'] != null
          ? (json['adjustments'] as List)
              .map((e) => PayrollAdjustment.fromJson(e))
              .toList()
          : [],
    );
  }
}

class PayrollRun {
  final String id;
  final String payPeriod; // "August 2026"
  final PayrollStatus status;
  final int totalEmployees;
  final double totalGrossPayout;
  final double totalDeductions;
  final double totalNetPayout;
  final DateTime processedDate;
  final bool isLocked;

  PayrollRun({
    required this.id,
    required this.payPeriod,
    required this.status,
    required this.totalEmployees,
    required this.totalGrossPayout,
    required this.totalDeductions,
    required this.totalNetPayout,
    required this.processedDate,
    this.isLocked = false,
  });

  String get formattedTotalNet =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalNetPayout);
  String get formattedTotalGross =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalGrossPayout);
  String get formattedTotalDeductions =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalDeductions);
}

class SalaryPackage {
  final String id;
  final String employeeId;
  final String employeeName;
  final double annualCtc;
  final double monthlyGross;
  final bool isPfApplicable;
  final bool isEsiApplicable;

  SalaryPackage({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.annualCtc,
  })  : monthlyGross = annualCtc / 12,
        isPfApplicable = true,
        isEsiApplicable = (annualCtc / 12) <= 21000;

  String get formattedCtc =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(annualCtc);
  String get formattedMonthlyGross =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(monthlyGross);
}

/// Helper utility to convert a number to Indian currency words
String numberToWords(double number) {
  final int val = number.round();
  if (val == 0) return "Zero Rupees";

  final units = [
    "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
    "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
    "Seventeen", "Eighteen", "Nineteen"
  ];

  final tens = [
    "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
  ];

  String convertChunk(int n) {
    if (n < 20) return units[n];
    if (n < 100) return "${tens[n ~/ 10]} ${units[n % 10]}".trim();
    if (n < 1000) return "${units[n ~/ 100]} Hundred ${convertChunk(n % 100)}".trim();
    return "";
  }

  int temp = val;
  String result = "";

  if (temp >= 10000000) {
    result += "${convertChunk(temp ~/ 10000000)} Crore ";
    temp %= 10000000;
  }
  if (temp >= 100000) {
    result += "${convertChunk(temp ~/ 100000)} Lakh ";
    temp %= 100000;
  }
  if (temp >= 1000) {
    result += "${convertChunk(temp ~/ 1000)} Thousand ";
    temp %= 1000;
  }
  if (temp > 0) {
    result += convertChunk(temp);
  }

  return "Rupees ${result.trim()} Only";
}

// [mod:2026-02-25T09:00:00+05:30]

// [rev:2026-08-25T13:00:00+05:30]
