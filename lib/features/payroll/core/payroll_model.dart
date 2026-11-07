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
  String get formattedNetSalary => formattedNetPay;
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

// ==========================================
// 1. Settings & Setup Models
// ==========================================

class PayrollSettings {
  final String currency;
  final String payrollFrequency;
  final String roundingMethod;
  final int roundingPrecision;
  final String lopCalculationMethod;
  final int lopFixedDaysValue;
  final double lopFactorPresent;
  final double lopFactorHalfDay;
  final double lopFactorAbsent;

  const PayrollSettings({
    this.currency = 'INR',
    this.payrollFrequency = 'monthly',
    this.roundingMethod = 'nearest',
    this.roundingPrecision = 0,
    this.lopCalculationMethod = 'Calendar Days',
    this.lopFixedDaysValue = 30,
    this.lopFactorPresent = 1.0,
    this.lopFactorHalfDay = 0.5,
    this.lopFactorAbsent = 0.0,
  });

  factory PayrollSettings.fromJson(Map<String, dynamic> json) {
    return PayrollSettings(
      currency: json['currency']?.toString() ?? 'INR',
      payrollFrequency: json['payrollFrequency']?.toString() ?? json['payroll_frequency']?.toString() ?? 'monthly',
      roundingMethod: json['roundingMethod']?.toString() ?? json['rounding_method']?.toString() ?? 'nearest',
      roundingPrecision: _toInt(json['roundingPrecision'] ?? json['rounding_precision'], 0),
      lopCalculationMethod: json['lopCalculationMethod']?.toString() ?? json['lop_calculation_method']?.toString() ?? 'Calendar Days',
      lopFixedDaysValue: _toInt(json['lopFixedDaysValue'] ?? json['lop_fixed_days_value'], 30),
      lopFactorPresent: _toDouble(json['lopFactorPresent'] ?? json['lop_factor_present'] ?? 1.0),
      lopFactorHalfDay: _toDouble(json['lopFactorHalfDay'] ?? json['lop_factor_half_day'] ?? 0.5),
      lopFactorAbsent: _toDouble(json['lopFactorAbsent'] ?? json['lop_factor_absent'] ?? 0.0),
    );
  }

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'payrollFrequency': payrollFrequency,
    'roundingMethod': roundingMethod,
    'roundingPrecision': roundingPrecision,
    'lopCalculationMethod': lopCalculationMethod,
    'lopFixedDaysValue': lopFixedDaysValue,
    'lopFactorPresent': lopFactorPresent,
    'lopFactorHalfDay': lopFactorHalfDay,
    'lopFactorAbsent': lopFactorAbsent,
  };
}

class PayrollSetupStatus {
  final bool isConfigured;
  final int packagesCount;
  final PayrollSettings? settings;

  const PayrollSetupStatus({
    required this.isConfigured,
    required this.packagesCount,
    this.settings,
  });

  factory PayrollSetupStatus.fromJson(Map<String, dynamic> json) {
    final isConf = json['is_configured'] == true ||
        json['is_settings_configured'] == true ||
        (json['settings'] != null && json['settings']['is_configured'] == true);
    final count = _toInt(json['packages_count']);
    final sJson = json['settings'] is Map<String, dynamic> ? json['settings'] as Map<String, dynamic> : null;
    return PayrollSetupStatus(
      isConfigured: isConf,
      packagesCount: count,
      settings: sJson != null ? PayrollSettings.fromJson(sJson) : null,
    );
  }
}

// ==========================================
// 2. Salary Package & Component Models
// ==========================================

class SalaryComponent {
  final int? id;
  final int? packageId;
  final String name;
  final String category; // 'earning', 'deduction', 'employer_contribution', 'benefit'
  final String calcType; // 'fixed', 'percent_of_gross', 'percent_of_component'
  final double value;
  final String? baseComponentName;
  final int sortOrder;

  const SalaryComponent({
    this.id,
    this.packageId,
    required this.name,
    this.category = 'earning',
    this.calcType = 'fixed',
    required this.value,
    this.baseComponentName,
    this.sortOrder = 0,
  });

  bool get isEarning => category.toLowerCase() == 'earning';
  bool get isDeduction => category.toLowerCase() == 'deduction';
  bool get isEmployerContribution =>
      category.toLowerCase() == 'employer_contribution' ||
      category.toLowerCase() == 'employer_cost' ||
      category.toLowerCase() == 'employer';
  bool get isBenefit => category.toLowerCase() == 'benefit' || category.toLowerCase() == 'benefits';

  String get categoryLabel {
    if (isEarning) return 'Earning (+)';
    if (isDeduction) return 'Deduction (-)';
    if (isEmployerContribution) return 'Employer Cost (CTC)';
    if (isBenefit) return 'Benefit (Perk)';
    return category;
  }

  factory SalaryComponent.fromJson(Map<String, dynamic> json) {
    return SalaryComponent(
      id: json['id'] != null ? _toInt(json['id']) : null,
      packageId: json['package_id'] != null ? _toInt(json['package_id']) : null,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'earning',
      calcType: json['calc_type']?.toString() ?? 'fixed',
      value: _toDouble(json['value']),
      baseComponentName: json['base_component_name']?.toString(),
      sortOrder: _toInt(json['sort_order'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (packageId != null) 'package_id': packageId,
    'name': name,
    'category': category,
    'calc_type': calcType,
    'value': value,
    if (baseComponentName != null) 'base_component_name': baseComponentName,
    'sort_order': sortOrder,
  };
}

class SalaryPackage {
  final String id;
  final String name;
  final String? description;
  final String employeeId;
  final String employeeName;
  final double annualCtc;
  final double monthlyGross;
  final bool isPfApplicable;
  final bool isEsiApplicable;
  final bool overtimeEnabled;
  final double overtimeRate;
  final bool lopEnabled;
  final String lopBasis;
  final String lopDayBasis;
  final double halfDayMultiplier;
  final List<SalaryComponent> components;
  final String? effectiveFrom;

  SalaryPackage({
    required this.id,
    String? name,
    this.description,
    this.employeeId = '',
    this.employeeName = '',
    double? annualCtc,
    double? monthlyGross,
    this.isPfApplicable = true,
    bool? isEsiApplicable,
    this.overtimeEnabled = true,
    this.overtimeRate = 150.0,
    this.lopEnabled = true,
    this.lopBasis = 'gross',
    this.lopDayBasis = 'calendar_days',
    this.halfDayMultiplier = 0.5,
    this.components = const [],
    this.effectiveFrom,
  })  : name = name ?? (employeeName.isNotEmpty ? '$employeeName Package' : 'Standard Package'),
        monthlyGross = monthlyGross ?? ((annualCtc != null && annualCtc > 0) ? annualCtc / 12 : 0.0),
        annualCtc = annualCtc ?? ((monthlyGross != null && monthlyGross > 0) ? monthlyGross * 12 : 0.0),
        isEsiApplicable = isEsiApplicable ?? ((monthlyGross ?? 0.0) <= 21000);

  String get formattedCtc =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(annualCtc);
  String get formattedMonthlyGross =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(monthlyGross);

  int get earningsCount => components.where((c) => c.isEarning).length;
  int get deductionsCount => components.where((c) => c.isDeduction).length;
  int get employerContributionsCount => components.where((c) => c.isEmployerContribution).length;
  int get benefitsCount => components.where((c) => c.isBenefit).length;

  factory SalaryPackage.fromJson(Map<String, dynamic> json) {
    final pkgId = (json['id'] ?? json['package_group_id'] ?? json['package_id'] ?? '').toString();
    final pName = json['name']?.toString() ?? json['package_name']?.toString() ?? 'Unnamed Package';
    final desc = json['description']?.toString();
    final activeRate = json['active_rate'] as Map<String, dynamic>?;
    final rules = json['packages_rules'] as Map<String, dynamic>?;
    final lopRules = rules != null ? (rules['lop'] as Map<String, dynamic>?) : null;
    final otRules = rules != null ? (rules['ot'] as Map<String, dynamic>?) : null;

    final gross = _toDouble(activeRate != null ? activeRate['gross_salary'] : (json['gross_salary'] ?? json['monthly_gross']));
    final ot = otRules != null
        ? (otRules['enabled'] == 1 || otRules['enabled'] == true)
        : (activeRate != null
            ? (activeRate['overtime_enabled'] == 1 || activeRate['overtime_enabled'] == true)
            : (json['overtime_enabled'] == 1 || json['overtime_enabled'] == true));
    final otRate = _toDouble(
      otRules != null
          ? otRules['hourly_rate']
          : (activeRate != null ? activeRate['overtime_rate'] : json['overtime_rate']),
    );
    final rawComps = json['components'] as List? ?? [];
    final comps = rawComps.map((c) => SalaryComponent.fromJson(c as Map<String, dynamic>)).toList();
    final effFrom = activeRate != null ? activeRate['effective_from']?.toString() : json['created_at']?.toString();

    final lopEn = lopRules != null
        ? (lopRules['enabled'] != false)
        : (json['lop_enabled'] != false);
    final lopB = lopRules != null
        ? (lopRules['basis']?.toString() ?? 'gross')
        : (json['lop_basis']?.toString() ?? 'gross');
    final lopDay = lopRules != null
        ? (lopRules['day_divisor']?.toString() ?? lopRules['day_basis']?.toString() ?? 'calendar_days')
        : (json['lop_day_basis']?.toString() ?? 'calendar_days');

    final halfDay = _toDouble(
      lopRules != null
          ? (lopRules['factor_half_day'] ?? lopRules['half_day_multiplier'])
          : (activeRate != null
              ? (activeRate['half_day_multiplier'] ?? activeRate['lop_factor_half_day'] ?? activeRate['halfDayMultiplier'] ?? activeRate['lopFactorHalfDay'])
              : (json['half_day_multiplier'] ?? json['lop_factor_half_day'] ?? json['halfDayMultiplier'] ?? json['lopFactorHalfDay'])),
    );

    return SalaryPackage(
      id: pkgId,
      name: pName,
      description: desc,
      monthlyGross: gross,
      annualCtc: gross * 12,
      overtimeEnabled: ot,
      overtimeRate: otRate > 0 ? otRate : 150.0,
      lopEnabled: lopEn,
      lopBasis: lopB,
      lopDayBasis: lopDay,
      halfDayMultiplier: halfDay > 0 ? halfDay : 0.5,
      components: comps,
      effectiveFrom: effFrom,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'grossSalary': monthlyGross,
    'overtimeEnabled': overtimeEnabled,
    'overtimeRate': overtimeRate,
    'lopEnabled': lopEnabled,
    'lopBasis': lopBasis,
    'lopDayBasis': lopDayBasis,
    'halfDayMultiplier': halfDayMultiplier,
    'half_day_multiplier': halfDayMultiplier,
    'lopFactorHalfDay': halfDayMultiplier,
    'lop_factor_half_day': halfDayMultiplier,
    'packages_rules': {
      'lop': {
        'enabled': lopEnabled,
        'basis': lopBasis,
        'day_divisor': lopDayBasis,
        'day_basis': lopDayBasis,
        'factor_present': 1.0,
        'factor_half_day': halfDayMultiplier,
        'factor_absent': 0.0,
      },
      'ot': {
        'enabled': overtimeEnabled,
        'rate_basis': 'hourly',
        'hourly_rate': overtimeRate,
        'multiplier': 1.5,
      },
    },
    'effectiveFrom': effectiveFrom,
    'components': components.map((c) => c.toJson()).toList(),
  };
}

// ==========================================
// 3. Employee Package Assignment Models
// ==========================================

class EmployeePackageAssignment {
  final int employeeId;
  final String name;
  final String code;
  final String department;
  final String designation;
  final int? packageId;
  final String? packageName;
  final double grossSalary;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String status; // 'assigned' | 'unassigned'

  const EmployeePackageAssignment({
    required this.employeeId,
    required this.name,
    this.code = '',
    this.department = 'General',
    this.designation = 'Staff',
    this.packageId,
    this.packageName,
    this.grossSalary = 0.0,
    this.effectiveFrom,
    this.effectiveTo,
    this.status = 'unassigned',
  });

  bool get isAssigned => packageId != null && packageId! > 0;

  factory EmployeePackageAssignment.fromJson(Map<String, dynamic> json) {
    final empId = _toInt(json['employee_id'] ?? json['user_id'] ?? json['id']);
    final pkgId = json['package_id'] != null
        ? _toInt(json['package_id'])
        : (json['package_group_id'] != null ? _toInt(json['package_group_id']) : null);
    final gross = _toDouble(json['gross_salary'] ??
        json['monthly_gross'] ??
        (json['active_rate'] != null ? json['active_rate']['gross_salary'] : 0.0));
    return EmployeePackageAssignment(
      employeeId: empId,
      name: json['name']?.toString() ?? json['user_name']?.toString() ?? 'Staff Member',
      code: json['code']?.toString() ?? json['user_code']?.toString() ?? json['employee_code']?.toString() ?? '',
      department: json['department']?.toString() ?? json['dept_name']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? json['desg_name']?.toString() ?? 'Staff',
      packageId: pkgId,
      packageName: json['package_name']?.toString() ?? json['name']?.toString(),
      grossSalary: gross,
      effectiveFrom: json['effective_from']?.toString(),
      effectiveTo: json['effective_to']?.toString(),
      status: (pkgId != null && pkgId > 0) ? 'assigned' : 'unassigned',
    );
  }
}

// ==========================================
// 4. Payroll Run & Breakdown Models
// ==========================================

class PayrollRunSummary {
  final int employeeCount;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;

  const PayrollRunSummary({
    this.employeeCount = 0,
    this.totalGross = 0.0,
    this.totalDeductions = 0.0,
    this.totalNet = 0.0,
  });

  factory PayrollRunSummary.fromJson(Map<String, dynamic> json) {
    return PayrollRunSummary(
      employeeCount: _toInt(json['employee_count'] ?? json['count']),
      totalGross: _toDouble(json['total_gross'] ?? json['gross']),
      totalDeductions: _toDouble(json['total_deductions'] ?? json['deductions']),
      totalNet: _toDouble(json['total_net'] ?? json['net']),
    );
  }
}

class PayrollLineItem {
  final String name;
  final String transactionType; // 'earning', 'deduction', 'employer_contribution', 'adjustment'
  final double amount;
  final String? description;
  final int? salaryPackageComponentId;

  const PayrollLineItem({
    required this.name,
    required this.transactionType,
    required this.amount,
    this.description,
    this.salaryPackageComponentId,
  });

  bool get isDeduction => transactionType.toLowerCase() == 'deduction' || amount < 0;
  bool get isEarning => transactionType.toLowerCase() == 'earning' || transactionType.toLowerCase() == 'addition';

  factory PayrollLineItem.fromJson(Map<String, dynamic> json) {
    return PayrollLineItem(
      name: json['name']?.toString() ?? 'Adjustment',
      transactionType: json['transaction_type']?.toString() ?? 'earning',
      amount: _toDouble(json['amount']),
      description: json['description']?.toString(),
      salaryPackageComponentId: json['salary_package_component_id'] != null ? _toInt(json['salary_package_component_id']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'transaction_type': transactionType,
    'amount': amount,
    'description': description,
    'salary_package_component_id': salaryPackageComponentId,
  };
}

class PayrollRunEmployee {
  final int employeeId;
  final String employeeName;
  final String employeeCode;
  final String department;
  final String designation;
  final double grossPay;
  final double totalDeductions;
  final double netPay;
  final List<PayrollLineItem> lines;

  const PayrollRunEmployee({
    required this.employeeId,
    required this.employeeName,
    this.employeeCode = '',
    this.department = 'General',
    this.designation = 'Staff',
    this.grossPay = 0.0,
    this.totalDeductions = 0.0,
    this.netPay = 0.0,
    this.lines = const [],
  });

  PayrollLineItem? get lopLine {
    for (final l in lines) {
      final n = l.name.toLowerCase();
      if (n.contains('loss of pay') || n.contains('lop')) return l;
    }
    return null;
  }

  PayrollLineItem? get otLine {
    for (final l in lines) {
      if (l.name.toLowerCase().contains('overtime')) return l;
    }
    return null;
  }

  factory PayrollRunEmployee.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? [];
    final linesList = rawLines.map((l) => PayrollLineItem.fromJson(l as Map<String, dynamic>)).toList();
    return PayrollRunEmployee(
      employeeId: _toInt(json['employee_id'] ?? json['user_id'] ?? json['id']),
      employeeName: json['employee_name']?.toString() ?? json['user_name']?.toString() ?? json['name']?.toString() ?? 'Staff',
      employeeCode: json['employee_code']?.toString() ?? json['user_code']?.toString() ?? json['code']?.toString() ?? '',
      department: json['department']?.toString() ?? json['dept_name']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? json['desg_name']?.toString() ?? 'Staff',
      grossPay: _toDouble(json['gross_pay'] ?? json['gross_salary']),
      totalDeductions: _toDouble(json['total_deductions'] ?? json['deductions']),
      netPay: _toDouble(json['net_pay'] ?? json['net_salary']),
      lines: linesList,
    );
  }
}

class PayrollRun {
  final String id;
  final String? batchName;
  final String runType; // 'batch' | 'individual'
  final String payPeriod; // "August 2026" or "2026-08-01 to 2026-08-31"
  final String? periodStart;
  final String? periodEnd;
  final PayrollStatus status;
  final int totalEmployees;
  final double totalGrossPayout;
  final double totalDeductions;
  final double totalNetPayout;
  final DateTime processedDate;
  final String? paidAt;
  final bool isLocked;
  final PayrollRunSummary summary;
  final List<PayrollRunEmployee> employees;

  PayrollRun({
    required this.id,
    this.batchName,
    this.runType = 'batch',
    required this.payPeriod,
    this.periodStart,
    this.periodEnd,
    required this.status,
    required this.totalEmployees,
    required this.totalGrossPayout,
    required this.totalDeductions,
    required this.totalNetPayout,
    required this.processedDate,
    this.paidAt,
    this.isLocked = false,
    PayrollRunSummary? summary,
    this.employees = const [],
  }) : summary = summary ??
            PayrollRunSummary(
              employeeCount: totalEmployees,
              totalGross: totalGrossPayout,
              totalDeductions: totalDeductions,
              totalNet: totalNetPayout,
            );

  String get formattedTotalNet =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalNetPayout);
  String get formattedTotalGross =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalGrossPayout);
  String get formattedTotalDeductions =>
      NumberFormat.currency(symbol: '₹ ', decimalDigits: 0).format(totalDeductions);

  factory PayrollRun.fromApi(Map<String, dynamic> json) {
    final idVal = json['id']?.toString() ?? '';
    final bName = json['batch_name']?.toString();
    final rType = json['run_type']?.toString() ?? 'batch';
    final pStart = json['period_start']?.toString() ?? '';
    final pEnd = json['period_end']?.toString() ?? '';
    final statusStr = json['status']?.toString().toLowerCase() ?? 'draft';
    final paidAtStr = json['paid_at']?.toString();

    PayrollStatus s = PayrollStatus.draft;
    if (statusStr == 'paid') {
      s = PayrollStatus.paid;
    } else if (statusStr == 'approved') {
      s = PayrollStatus.approved;
    } else if (statusStr == 'finalized') {
      s = PayrollStatus.finalized;
    } else if (statusStr == 'processing') {
      s = PayrollStatus.processing;
    }

    final summaryRaw = json['summary'] as Map<String, dynamic>?;
    final sumObj = summaryRaw != null ? PayrollRunSummary.fromJson(summaryRaw) : null;

    final rawEmps = json['employees'] as List? ?? [];
    final empList = rawEmps.map((e) => PayrollRunEmployee.fromJson(e as Map<String, dynamic>)).toList();

    final count = sumObj?.employeeCount ?? (empList.isNotEmpty ? empList.length : _toInt(json['total_employees']));
    final gross = sumObj?.totalGross ?? _toDouble(json['total_gross']);
    final ded = sumObj?.totalDeductions ?? _toDouble(json['total_deductions']);
    final net = sumObj?.totalNet ?? _toDouble(json['total_net']);

    return PayrollRun(
      id: idVal,
      batchName: bName,
      runType: rType,
      payPeriod: bName ?? (pStart.isNotEmpty && pEnd.isNotEmpty ? '$pStart to $pEnd' : 'Run #$idVal'),
      periodStart: pStart,
      periodEnd: pEnd,
      status: s,
      totalEmployees: count,
      totalGrossPayout: gross,
      totalDeductions: ded,
      totalNetPayout: net,
      processedDate: json['created_at'] != null ? (DateTime.tryParse(json['created_at']) ?? DateTime.now()) : DateTime.now(),
      paidAt: paidAtStr,
      isLocked: s == PayrollStatus.approved || s == PayrollStatus.paid || s == PayrollStatus.finalized,
      summary: sumObj,
      employees: empList,
    );
  }
}

// ==========================================
// 5. Itemized Payslip Model (Web Parity)
// ==========================================

class ItemizedPayslip {
  final int runId;
  final String? runType;
  final String? periodStart;
  final String? periodEnd;
  final String? status;
  final String? paidAt;
  final String employeeName;
  final String employeeCode;
  final String department;
  final String designation;
  final String workLocation;
  final String orgName;
  final int employeeId;
  final double presentDays;
  final double absentDays;
  final double halfDays;
  final double holidays;
  final double weeklyOff;
  final int calendarDays;
  final List<PayrollLineItem> earnings;
  final List<PayrollLineItem> deductions;
  final List<PayrollLineItem> employerContributions;
  final double grossPay;
  final double totalDeductions;
  final double netPay;

  const ItemizedPayslip({
    required this.runId,
    this.runType,
    this.periodStart,
    this.periodEnd,
    this.status,
    this.paidAt,
    required this.employeeName,
    this.employeeCode = '',
    this.department = 'General',
    this.designation = 'Staff',
    this.workLocation = '',
    this.orgName = 'MANO TECHNOLOGIES',
    required this.employeeId,
    this.presentDays = 0,
    this.absentDays = 0,
    this.halfDays = 0,
    this.holidays = 0,
    this.weeklyOff = 0,
    this.calendarDays = 30,
    this.earnings = const [],
    this.deductions = const [],
    this.employerContributions = const [],
    this.grossPay = 0,
    this.totalDeductions = 0,
    this.netPay = 0,
  });

  factory ItemizedPayslip.fromJson(Map<String, dynamic> json) {
    final empJson = json['employee'] as Map<String, dynamic>? ?? {};
    final attJson = json['attendance'] as Map<String, dynamic>? ?? {};
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};

    final rawLines = json['lines'] as List? ?? [];
    final allLines = rawLines.map((l) => PayrollLineItem.fromJson(l as Map<String, dynamic>)).toList();

    final earnings = (json['earnings'] as List?)?.map((e) => PayrollLineItem.fromJson(e as Map<String, dynamic>)).toList() ??
        allLines.where((l) => l.transactionType.toLowerCase() == 'earning').toList();

    final deductions = (json['deductions'] as List?)?.map((d) => PayrollLineItem.fromJson(d as Map<String, dynamic>)).toList() ??
        allLines.where((l) => l.transactionType.toLowerCase() == 'deduction').toList();

    final employerContributions = (json['employer_contributions'] as List?)?.map((c) => PayrollLineItem.fromJson(c as Map<String, dynamic>)).toList() ??
        allLines.where((l) => l.transactionType.toLowerCase() == 'employer_contribution' || l.transactionType.toLowerCase() == 'benefit').toList();

    return ItemizedPayslip(
      runId: _toInt(json['run_id']),
      runType: json['run_type']?.toString(),
      periodStart: json['period_start']?.toString(),
      periodEnd: json['period_end']?.toString(),
      status: json['status']?.toString(),
      paidAt: json['paid_at']?.toString(),
      employeeName: empJson['user_name']?.toString() ?? empJson['employee_name']?.toString() ?? empJson['name']?.toString() ?? 'Staff Member',
      employeeCode: empJson['user_code']?.toString() ?? empJson['employee_code']?.toString() ?? empJson['code']?.toString() ?? '',
      department: empJson['dept_name']?.toString() ?? empJson['department']?.toString() ?? 'General',
      designation: empJson['desg_name']?.toString() ?? empJson['designation']?.toString() ?? 'Staff',
      workLocation: empJson['work_location']?.toString() ?? '',
      orgName: empJson['org_name']?.toString() ?? 'MANO TECHNOLOGIES',
      employeeId: _toInt(empJson['user_id'] ?? empJson['employee_id'] ?? json['employee_id']),
      presentDays: _toDouble(attJson['present_days'] ?? attJson['present']),
      absentDays: _toDouble(attJson['absent_days'] ?? attJson['absent'] ?? attJson['lop_days']),
      halfDays: _toDouble(attJson['half_days'] ?? attJson['half_day']),
      holidays: _toDouble(attJson['holiday_days'] ?? attJson['holidays']),
      weeklyOff: _toDouble(attJson['weekly_off_days'] ?? attJson['weekly_off']),
      calendarDays: _toInt(attJson['calendar_days'] ?? attJson['total_working_days'], 30),
      earnings: earnings,
      deductions: deductions,
      employerContributions: employerContributions,
      grossPay: _toDouble(summaryJson['gross_pay'] ?? json['gross_pay']),
      totalDeductions: _toDouble(summaryJson['total_deductions'] ?? json['total_deductions']),
      netPay: _toDouble(summaryJson['net_pay'] ?? json['net_pay']),
    );
  }
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
