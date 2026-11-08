import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/widgets/custom_month_picker_dialog.dart';
import 'package:flutter_application/features/reports/widgets/custom_dropdown_selector.dart';
import 'package:flutter_application/features/reports/widgets/full_report_filters_panel.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';

class ReportFilterCard extends StatelessWidget {
  final String selectedReportType;
  final ValueChanged<String> onReportTypeChanged;

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  final ReportWeekOption? selectedWeek;
  final ValueChanged<ReportWeekOption>? onWeekChanged;

  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime start, DateTime end) onDateRangeChanged;
  final bool useDateRange;
  final ValueChanged<bool> onToggleDateRange;

  final String selectedDept;
  final ValueChanged<String> onDeptChanged;
  final List<String> departments;

  final String selectedDesg;
  final ValueChanged<String>? onDesgChanged;
  final List<String> designations;

  final String selectedShift;
  final ValueChanged<String>? onShiftChanged;
  final List<String> shifts;

  final String? selectedEmployeeId;
  final ValueChanged<String?>? onEmployeeChanged;
  final List<Map<String, dynamic>> employees;

  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;

  final Map<String, bool>? exportColumns;
  final Function(String key, bool val)? onColumnToggled;

  final VoidCallback onGenerate;
  final VoidCallback onExport;
  final VoidCallback onToggleHistory;

  final bool isGenerating;
  final bool isExporting;
  final bool isCompact;
  final bool isTabletPortrait;
  final bool isEmployee;

  const ReportFilterCard({
    super.key,
    required this.selectedReportType,
    required this.onReportTypeChanged,
    required this.selectedDate,
    required this.onDateChanged,
    this.selectedWeek,
    this.onWeekChanged,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.useDateRange,
    required this.onToggleDateRange,
    required this.selectedDept,
    required this.onDeptChanged,
    this.departments = const ['All Departments'],
    this.selectedDesg = 'All Designations',
    this.onDesgChanged,
    this.designations = const ['All Designations'],
    this.selectedShift = 'All Shifts',
    this.onShiftChanged,
    this.shifts = const ['All Shifts'],
    this.selectedEmployeeId,
    this.onEmployeeChanged,
    this.employees = const [],
    required this.selectedFormat,
    required this.onFormatChanged,
    this.exportColumns,
    this.onColumnToggled,
    required this.onGenerate,
    required this.onExport,
    required this.onToggleHistory,
    this.isGenerating = false,
    this.isExporting = false,
    this.isCompact = false,
    this.isTabletPortrait = false,
    this.isEmployee = false,
  });

  static const List<DropdownOption<String>> reportTypeOptions = [
    DropdownOption(
      value: 'matrix_daily',
      label: 'Daily Attendance Report',
      subtitle: 'Single-day punch status & hours',
      icon: Icons.today_rounded,
    ),
    DropdownOption(
      value: 'matrix_weekly',
      label: 'Weekly Attendance Report',
      subtitle: '7-day muster roll register',
      icon: Icons.view_week_rounded,
    ),
    DropdownOption(
      value: 'matrix_monthly',
      label: 'Monthly Attendance Report',
      subtitle: 'Muster roll attendance register',
      icon: Icons.calendar_view_month_rounded,
    ),
    DropdownOption(
      value: 'attendance_summary',
      label: 'Monthly Summary Report',
      subtitle: 'Total present, absent, leaves & hours',
      icon: Icons.summarize_outlined,
    ),
    DropdownOption(
      value: 'employee_master',
      label: 'Employee Master Data',
      subtitle: 'Complete workforce details & metadata',
      icon: Icons.badge_outlined,
    ),
  ];

  List<DropdownOption<String>> get activeReportTypeOptions {
    if (isEmployee) {
      return reportTypeOptions.where((opt) => opt.value != 'employee_master').toList();
    }
    return reportTypeOptions;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final deptOptions = departments.map((d) {
      return DropdownOption<String>(
        value: d,
        label: d,
        icon: d == 'All Departments' ? Icons.domain_rounded : Icons.business_outlined,
      );
    }).toList();

    final desgOptions = designations.map((d) {
      return DropdownOption<String>(
        value: d,
        label: d,
        icon: d == 'All Designations' ? Icons.work_outline : Icons.badge_outlined,
      );
    }).toList();

    final shiftOptions = shifts.map((s) {
      return DropdownOption<String>(
        value: s,
        label: s,
        icon: s == 'All Shifts' ? Icons.schedule_rounded : Icons.access_time_rounded,
      );
    }).toList();

    final employeeOptions = [
      const DropdownOption<String>(
        value: '',
        label: 'All Employees',
        subtitle: 'View whole workforce',
        icon: Icons.groups_rounded,
      ),
      ...employees.map((e) {
        final uid = (e['user_id'] ?? e['id'] ?? '').toString();
        final name = (e['user_name'] ?? e['name'] ?? 'Staff').toString();
        final code = (e['employee_id'] ?? e['emp_id'] ?? uid).toString();
        final desg = (e['designation'] ?? e['desg_name'] ?? '').toString();
        return DropdownOption<String>(
          value: uid,
          label: name,
          subtitle: "$code${desg.isNotEmpty ? ' • $desg' : ''}",
          icon: Icons.person_outline_rounded,
        );
      }),
    ];

    if (isCompact) {
      return _buildMobileCard(
        context,
        isDark,
        deptOptions,
        desgOptions,
        shiftOptions,
        employeeOptions,
      );
    }

    if (isTabletPortrait) {
      return _buildTabletPortraitCard(
        context,
        isDark,
        deptOptions,
        desgOptions,
        shiftOptions,
        employeeOptions,
      );
    }

    return _buildDesktopTabletCard(
      context,
      isDark,
      deptOptions,
      desgOptions,
      shiftOptions,
      employeeOptions,
    );
  }

  // ── Tablet Portrait Filter Card (Balanced 2-Column Layout) ───────────────
  Widget _buildTabletPortraitCard(
    BuildContext context,
    bool isDark,
    List<DropdownOption<String>> deptOptions,
    List<DropdownOption<String>> desgOptions,
    List<DropdownOption<String>> shiftOptions,
    List<DropdownOption<String>> employeeOptions,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Report Type & Date Selector
          Row(
            children: [
              Expanded(
                child: CustomDropdownSelector<String>(
                  label: "Report Type",
                  placeholder: "Select Report Type",
                  icon: Icons.description_outlined,
                  selectedValue: selectedReportType,
                  options: activeReportTypeOptions,
                  onSelected: onReportTypeChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomDateTrigger(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Department & Designation
          Row(
            children: [
              Expanded(
                child: CustomDropdownSelector<String>(
                  label: "Department",
                  placeholder: "All Departments",
                  icon: Icons.business_outlined,
                  selectedValue: selectedDept,
                  options: deptOptions,
                  onSelected: onDeptChanged,
                  isSearchable: true,
                ),
              ),
              if (onDesgChanged != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Designation",
                    placeholder: "All Designations",
                    icon: Icons.work_outline_rounded,
                    selectedValue: selectedDesg,
                    options: desgOptions,
                    onSelected: onDesgChanged!,
                    isSearchable: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Shift & Employee
          Row(
            children: [
              if (onShiftChanged != null) ...[
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Shift",
                    placeholder: "All Shifts",
                    icon: Icons.schedule_rounded,
                    selectedValue: selectedShift,
                    options: shiftOptions,
                    onSelected: onShiftChanged!,
                    isSearchable: true,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (onEmployeeChanged != null) ...[
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Employee",
                    placeholder: "All Employees",
                    icon: Icons.person_search_rounded,
                    selectedValue: selectedEmployeeId ?? '',
                    options: employeeOptions,
                    onSelected: (val) => onEmployeeChanged!(val.isEmpty ? null : val),
                    isSearchable: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Format Selector & Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _buildFormatSelector(isDark),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isGenerating ? null : onGenerate,
                icon: isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  "Generate",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isExporting ? null : onExport,
                icon: isExporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  "Export",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onToggleHistory,
                icon: const Icon(Icons.history_rounded, size: 20),
                tooltip: "Download History",
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildColumnToggles(isDark),
        ],
      ),
    );
  }

  // ── Desktop / Tablet Landscape Filter Card ──────────────────────────────
  Widget _buildDesktopTabletCard(
    BuildContext context,
    bool isDark,
    List<DropdownOption<String>> deptOptions,
    List<DropdownOption<String>> desgOptions,
    List<DropdownOption<String>> shiftOptions,
    List<DropdownOption<String>> employeeOptions,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Report Type, Date, Department, Designation
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CustomDropdownSelector<String>(
                  label: "Report Type",
                  placeholder: "Select Report Type",
                  icon: Icons.description_outlined,
                  selectedValue: selectedReportType,
                  options: activeReportTypeOptions,
                  onSelected: onReportTypeChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildCustomDateTrigger(context, isDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CustomDropdownSelector<String>(
                  label: "Department",
                  placeholder: "All Departments",
                  icon: Icons.business_outlined,
                  selectedValue: selectedDept,
                  options: deptOptions,
                  onSelected: onDeptChanged,
                  isSearchable: true,
                ),
              ),
              if (onDesgChanged != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: CustomDropdownSelector<String>(
                    label: "Designation",
                    placeholder: "All Designations",
                    icon: Icons.work_outline_rounded,
                    selectedValue: selectedDesg,
                    options: desgOptions,
                    onSelected: onDesgChanged!,
                    isSearchable: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Shift, Employee, Format, Actions
          Row(
            children: [
              if (onShiftChanged != null) ...[
                Expanded(
                  flex: 2,
                  child: CustomDropdownSelector<String>(
                    label: "Shift",
                    placeholder: "All Shifts",
                    icon: Icons.schedule_rounded,
                    selectedValue: selectedShift,
                    options: shiftOptions,
                    onSelected: onShiftChanged!,
                    isSearchable: true,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (onEmployeeChanged != null) ...[
                Expanded(
                  flex: 3,
                  child: CustomDropdownSelector<String>(
                    label: "Employee",
                    placeholder: "All Employees",
                    icon: Icons.person_search_rounded,
                    selectedValue: selectedEmployeeId ?? '',
                    options: employeeOptions,
                    onSelected: (val) => onEmployeeChanged!(val.isEmpty ? null : val),
                    isSearchable: true,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: _buildFormatSelector(isDark),
              ),
              const SizedBox(width: 12),

              // Action Buttons: Generate, Export, History
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      "Generate",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isExporting ? null : onExport,
                    icon: isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      "Export",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onToggleHistory,
                    icon: const Icon(Icons.history_rounded, size: 20),
                    tooltip: "Recent History",
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildColumnToggles(isDark),
        ],
      ),
    );
  }

  int _countSelectedColumns() {
    if (exportColumns == null || exportColumns!.isEmpty) return 0;
    final allowedKeys = FullReportFiltersPanel.reportTypeColumnKeys[selectedReportType];
    final entries = allowedKeys != null
        ? exportColumns!.entries.where((e) => allowedKeys.contains(e.key)).toList()
        : exportColumns!.entries.toList();
    final list = entries.isNotEmpty ? entries : exportColumns!.entries.toList();
    return list.where((e) => e.value).length;
  }

  void _showColumnsModal(BuildContext context, bool isDark) {
    if (exportColumns == null || exportColumns!.isEmpty) return;

    final allowedKeys = FullReportFiltersPanel.reportTypeColumnKeys[selectedReportType];
    final entries = allowedKeys != null
        ? exportColumns!.entries.where((e) => allowedKeys.contains(e.key)).toList()
        : exportColumns!.entries.toList();
    final listToRender = entries.isNotEmpty ? entries : exportColumns!.entries.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Columns to Include",
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "Done",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: listToRender.map((entry) {
                            final key = entry.key;
                            final isChecked = exportColumns?[key] ?? entry.value;
                            final label = _formatColumnName(key);

                            return FilterChip(
                              label: Text(
                                label,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                                  color: isChecked
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                              selected: isChecked,
                              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isChecked
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              onSelected: (val) {
                                setModalState(() {});
                                if (onColumnToggled != null) {
                                  onColumnToggled!(key, val);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Mobile Compact Filter Card ──────────────────────────────────────────
  Widget _buildMobileCard(
    BuildContext context,
    bool isDark,
    List<DropdownOption<String>> deptOptions,
    List<DropdownOption<String>> desgOptions,
    List<DropdownOption<String>> shiftOptions,
    List<DropdownOption<String>> employeeOptions,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Report Type
          CustomDropdownSelector<String>(
            label: "Report Type",
            placeholder: "Select Report Type",
            icon: Icons.description_outlined,
            selectedValue: selectedReportType,
            options: activeReportTypeOptions,
            onSelected: onReportTypeChanged,
          ),
          const SizedBox(height: 6),

          // Row 2: Date Selector
          _buildCustomDateTrigger(context, isDark),
          const SizedBox(height: 6),

          // Row 3: Department & Designation (2 columns)
          Row(
            children: [
              Expanded(
                child: CustomDropdownSelector<String>(
                  label: "Department",
                  placeholder: "All Departments",
                  icon: Icons.business_outlined,
                  selectedValue: selectedDept,
                  options: deptOptions,
                  onSelected: onDeptChanged,
                  isSearchable: true,
                ),
              ),
              if (onDesgChanged != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Designation",
                    placeholder: "All Designations",
                    icon: Icons.work_outline_rounded,
                    selectedValue: selectedDesg,
                    options: desgOptions,
                    onSelected: onDesgChanged!,
                    isSearchable: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Row 4: Shift & Employee (2 columns)
          Row(
            children: [
              if (onShiftChanged != null) ...[
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Shift",
                    placeholder: "All Shifts",
                    icon: Icons.schedule_rounded,
                    selectedValue: selectedShift,
                    options: shiftOptions,
                    onSelected: onShiftChanged!,
                    isSearchable: true,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (onEmployeeChanged != null) ...[
                Expanded(
                  child: CustomDropdownSelector<String>(
                    label: "Employee",
                    placeholder: "All Employees",
                    icon: Icons.person_search_rounded,
                    selectedValue: selectedEmployeeId ?? '',
                    options: employeeOptions,
                    onSelected: (val) => onEmployeeChanged!(val.isEmpty ? null : val),
                    isSearchable: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Row 5: Columns Button + Format Selector
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Columns",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () => _showColumnsModal(context, isDark),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.view_column_outlined, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 5),
                                Text(
                                  "Columns (${_countSelectedColumns()})",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey[500]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 6,
                child: _buildFormatSelector(isDark),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 6: Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isGenerating ? null : onGenerate,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(
                    "Generate",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExporting ? null : onExport,
                  icon: isExporting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 15),
                  label: Text(
                    "Export",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onToggleHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Custom Date Trigger ─────────────────────────────────────────────────
  Widget _buildCustomDateTrigger(BuildContext context, bool isDark) {
    final isDaily = selectedReportType == 'matrix_daily';
    final isWeekly = selectedReportType == 'matrix_weekly';
    final isRange = useDateRange;

    final weeks = ReportWeekOption.getWeeksOfMonth(selectedDate);
    final currentWeek = selectedWeek ?? (weeks.isNotEmpty ? weeks.first : null);

    String displayText;
    if (isRange) {
      displayText = "${DateFormat('d MMM').format(startDate)} - ${DateFormat('d MMM yyyy').format(endDate)}";
    } else if (isDaily) {
      displayText = DateFormat('d MMMM yyyy').format(selectedDate);
    } else if (isWeekly) {
      displayText = currentWeek?.label ?? DateFormat('MMMM yyyy').format(selectedDate);
    } else {
      displayText = DateFormat('MMMM yyyy').format(selectedDate);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isDaily
                  ? "Date"
                  : (isRange ? "Custom Range" : (isWeekly ? "Week / Month" : "Month")),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              ),
            ),
            GestureDetector(
              onTap: () => onToggleDateRange(!useDateRange),
              child: Text(
                useDateRange
                    ? (isWeekly ? "Use Week" : (isDaily ? "Use Date" : "Use Month"))
                    : "Use Range",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (isWeekly && !useDateRange) ...[
          Row(
            children: [
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: () => _openDatePicker(context, isDark),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            DateFormat('MMM yyyy').format(selectedDate),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[500]),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 6,
                child: CustomDropdownSelector<String>(
                  label: "",
                  placeholder: "Select Week",
                  icon: Icons.view_week_rounded,
                  selectedValue: currentWeek?.value ?? (weeks.isNotEmpty ? weeks.first.value : ''),
                  options: weeks.map((w) => DropdownOption<String>(
                    value: w.value,
                    label: w.label,
                    icon: Icons.view_week_rounded,
                  )).toList(),
                  onSelected: (val) {
                    if (onWeekChanged != null) {
                      final found = weeks.firstWhere((w) => w.value == val, orElse: () => weeks.first);
                      onWeekChanged!(found);
                    }
                  },
                ),
              ),
            ],
          ),
        ] else ...[
          InkWell(
            onTap: () => _openDatePicker(context, isDark),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRange
                        ? Icons.date_range_rounded
                        : (isDaily ? Icons.calendar_today_rounded : Icons.calendar_month_rounded),
                    size: 15,
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayText,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openDatePicker(BuildContext context, bool isDark) {
    if (useDateRange) {
      showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        initialDateRange: DateTimeRange(start: startDate, end: endDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6366F1),
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
            ),
            child: child!,
          );
        },
      ).then((range) {
        if (range != null) {
          onDateRangeChanged(range.start, range.end);
        }
      });
    } else if (selectedReportType == 'matrix_daily') {
      showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      ).then((date) {
        if (date != null) {
          onDateChanged(date);
        }
      });
    } else {
      CustomMonthPickerDialog.show(
        context,
        initialDate: selectedDate,
      ).then((date) {
        if (date != null) {
          onDateChanged(date);
        }
      });
    }
  }

  // ── Format Selector ─────────────────────────────────────────────────────
  Widget _buildFormatSelector(bool isDark) {
    const formats = ['xlsx', 'csv', 'pdf'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Format",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 38,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: formats.map((fmt) {
              final isSel = selectedFormat.toLowerCase() == fmt;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onFormatChanged(fmt),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel
                          ? (isDark ? const Color(0xFF21262D) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSel && !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      fmt.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildColumnToggles(bool isDark) {
    if (exportColumns == null || exportColumns!.isEmpty) {
      return const SizedBox.shrink();
    }

    final allowedKeys = FullReportFiltersPanel.reportTypeColumnKeys[selectedReportType];
    final entries = allowedKeys != null
        ? exportColumns!.entries.where((e) => allowedKeys.contains(e.key)).toList()
        : exportColumns!.entries.toList();
    final listToRender = entries.isNotEmpty ? entries : exportColumns!.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          "EXPORT COLUMNS",
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: listToRender.map((entry) {
            final key = entry.key;
            final isChecked = entry.value;
            final label = _formatColumnName(key);

            return FilterChip(
              label: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                  color: isChecked
                      ? const Color(0xFF6366F1)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
              selected: isChecked,
              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
              backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isChecked
                      ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              onSelected: (val) {
                if (onColumnToggled != null) onColumnToggled!(key, val);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatColumnName(String key) {
    switch (key) {
      case 'shift':
        return 'Shift';
      case 'clock_in_out':
      case 'timeIn':
        return 'Time In';
      case 'timeOut':
        return 'Time Out';
      case 'status':
        return 'Status';
      case 'work_duration':
      case 'workedHours':
        return 'Worked Hours';
      case 'required_hours':
      case 'requiredHours':
        return 'Required Hours';
      case 'late_minutes':
      case 'late':
        return 'Lateness Info';
      case 'location':
        return 'Locations';
      case 'attendanceDays':
        return 'Attendance Summary';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }
}
