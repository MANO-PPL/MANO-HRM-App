import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/widgets/custom_month_picker_dialog.dart';
import 'package:flutter_application/features/reports/widgets/custom_dropdown_selector.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';

class FullReportFiltersPanel extends StatelessWidget {
  final bool isEmployee;
  final String selectedReportType;
  final ValueChanged<String> onReportTypeChanged;

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  final ReportWeekOption? selectedWeek;
  final ValueChanged<ReportWeekOption>? onWeekChanged;

  final bool useCustomDateRange;
  final ValueChanged<bool> onUseCustomRangeChanged;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime start, DateTime end)? onDateRangeChanged;

  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;

  final Map<String, bool> exportColumns;
  final Function(String key, bool val)? onColumnToggled;

  // Admin/HR specific dropdowns
  final List<String> departments;
  final String selectedDept;
  final ValueChanged<String>? onDeptChanged;

  final List<Map<String, dynamic>> employees;
  final String? selectedEmployeeId;
  final ValueChanged<String?>? onEmployeeChanged;
  final String? employeeName;

  final bool isGenerating;
  final bool isExporting;
  final VoidCallback onGeneratePreview;
  final VoidCallback onExportReport;
  final VoidCallback? onOpenHistory;

  const FullReportFiltersPanel({
    super.key,
    this.isEmployee = false,
    this.employeeName,
    required this.selectedReportType,
    required this.onReportTypeChanged,
    required this.selectedDate,
    required this.onDateChanged,
    this.selectedWeek,
    this.onWeekChanged,
    this.useCustomDateRange = false,
    required this.onUseCustomRangeChanged,
    required this.startDate,
    required this.endDate,
    this.onDateRangeChanged,
    this.selectedFormat = 'xlsx',
    required this.onFormatChanged,
    required this.exportColumns,
    this.onColumnToggled,
    this.departments = const ['All Departments'],
    this.selectedDept = 'All Departments',
    this.onDeptChanged,
    this.employees = const [],
    this.selectedEmployeeId,
    this.onEmployeeChanged,
    this.isGenerating = false,
    this.isExporting = false,
    required this.onGeneratePreview,
    required this.onExportReport,
    this.onOpenHistory,
  });

  static List<Map<String, String>> getReportTypeOptions(bool isEmployee) {
    const all = [
      {'id': 'matrix_daily', 'label': 'Daily Attendance Report', 'group': 'Attendance Reports'},
      {'id': 'matrix_weekly', 'label': 'Weekly Attendance Report', 'group': 'Attendance Reports'},
      {'id': 'matrix_monthly', 'label': 'Monthly Attendance Report', 'group': 'Attendance Reports'},
      {'id': 'attendance_summary', 'label': 'Monthly Summary Report', 'group': 'Summary'},
      {'id': 'employee_master', 'label': 'Employee Master Data', 'group': 'Employee Data'},
    ];
    if (isEmployee) {
      return all.where((opt) => opt['id'] != 'employee_master').toList();
    }
    return all;
  }

  static const Map<String, List<String>> reportTypeColumnKeys = {
    'matrix_daily': ['timeIn', 'timeOut', 'status', 'workedHours', 'late'],
    'matrix_weekly': ['position', 'workedHours', 'timeIn', 'timeOut', 'employeeCode', 'daysInMonth', 'presentDays', 'shift', 'status', 'requiredHours', 'late', 'location', 'attendanceDays'],
    'matrix_monthly': ['position', 'workedHours', 'timeIn', 'timeOut', 'employeeCode', 'daysInMonth', 'presentDays', 'shift', 'status', 'requiredHours', 'late', 'location', 'attendanceDays'],
    'attendance_summary': ['workedHours', 'requiredHours', 'late', 'attendanceDays'],
    'employee_master': ['employeeCode', 'position', 'location'],
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = getReportTypeOptions(isEmployee);
    final String effectiveValue = (options.any((opt) => opt['id'] == selectedReportType)
        ? selectedReportType
        : (options.isNotEmpty ? (options.first['id'] ?? selectedReportType) : selectedReportType));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Report Parameters & Filters",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (onOpenHistory != null)
                IconButton(
                  onPressed: onOpenHistory,
                  tooltip: "Download History",
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(7),
                  ),
                  icon: Icon(
                    Icons.history_rounded,
                    size: 17,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Report Type Dropdown (Custom)
          CustomDropdownSelector<String>(
            label: "Report Type",
            placeholder: "Select Report Type",
            icon: Icons.description_outlined,
            selectedValue: effectiveValue,
            options: options.map((opt) {
              return DropdownOption<String>(
                value: opt['id']!,
                label: opt['label']!,
                subtitle: opt['group'],
                icon: _getReportIcon(opt['id']!),
              );
            }).toList(),
            onSelected: onReportTypeChanged,
            isSearchable: true,
          ),
          const SizedBox(height: 12),

          // 2. Period Configuration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel("DATE / PERIOD", isDark),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Custom Range",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: useCustomDateRange,
                      activeTrackColor: const Color(0xFF6366F1),
                      onChanged: onUseCustomRangeChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (!useCustomDateRange) ...[
            if (selectedReportType == 'matrix_weekly')
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildMonthPickerButton(context, isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: _buildWeekDropdown(context, isDark),
                  ),
                ],
              )
            else if (selectedReportType == 'matrix_daily')
              _buildDailyDatePickerButton(context, isDark)
            else
              _buildMonthPickerButton(context, isDark),
          ]
          else
            // Date Range (Start & End)
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerTile(
                    context: context,
                    label: "Start Date",
                    date: startDate,
                    onPicked: (d) {
                      if (onDateRangeChanged != null) onDateRangeChanged!(d, endDate);
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDatePickerTile(
                    context: context,
                    label: "End Date",
                    date: endDate,
                    onPicked: (d) {
                      if (onDateRangeChanged != null) onDateRangeChanged!(startDate, d);
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // 3. Employee / Admin Entity Filters
          if (isEmployee) ...[
            _buildFieldLabel("EMPLOYEE", isDark),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      employeeName ?? 'My Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            CustomDropdownSelector<String>(
              label: "Department",
              placeholder: "All Departments",
              icon: Icons.business_outlined,
              selectedValue: selectedDept,
              options: departments.map((d) {
                return DropdownOption<String>(
                  value: d,
                  label: d,
                  icon: d == 'All Departments' ? Icons.domain_rounded : Icons.business_outlined,
                );
              }).toList(),
              onSelected: (val) {
                if (onDeptChanged != null) onDeptChanged!(val);
              },
              isSearchable: true,
            ),
            const SizedBox(height: 12),

            if (employees.isNotEmpty) ...[
              CustomDropdownSelector<String>(
                label: "Employee",
                placeholder: "All Employees",
                icon: Icons.person_search_rounded,
                selectedValue: selectedEmployeeId ?? '',
                options: [
                  const DropdownOption<String>(
                    value: '',
                    label: "All Employees",
                    subtitle: "Show all workforce records",
                    icon: Icons.people_outline_rounded,
                  ),
                  ...employees.map((emp) {
                    final id = emp['user_id']?.toString() ?? emp['id']?.toString() ?? '';
                    final name = emp['user_name'] ?? emp['name'] ?? id;
                    final code = emp['employee_id'] ?? emp['emp_id'] ?? '';
                    return DropdownOption<String>(
                      value: id,
                      label: name,
                      subtitle: code.isNotEmpty ? 'ID: $code' : null,
                      icon: Icons.person_outline_rounded,
                    );
                  }),
                ],
                onSelected: (val) {
                  if (onEmployeeChanged != null) {
                    onEmployeeChanged!(val.isEmpty ? null : val);
                  }
                },
                isSearchable: true,
              ),
              const SizedBox(height: 12),
            ],
          ],

          // 4. Column Customization Checkbox Chips
          _buildFieldLabel("EXPORT COLUMNS", isDark),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final allowedKeys = reportTypeColumnKeys[selectedReportType];
              final entries = allowedKeys != null
                  ? exportColumns.entries.where((e) => allowedKeys.contains(e.key)).toList()
                  : exportColumns.entries.toList();
              final listToRender = entries.isNotEmpty ? entries : exportColumns.entries.toList();

              return Wrap(
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
              );
            },
          ),
          const SizedBox(height: 14),

          // 5. File Format Selector
          _buildFieldLabel("FILE FORMAT", isDark),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildFormatChip("xlsx", "Excel (.xlsx)", Icons.grid_on_rounded, const Color(0xFF107C41), isDark),
              const SizedBox(width: 8),
              _buildFormatChip("csv", "CSV (.csv)", Icons.list_alt_rounded, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 8),
              _buildFormatChip("pdf", "PDF (.pdf)", Icons.picture_as_pdf_rounded, const Color(0xFFDC2626), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // 6. Action Buttons: Generate Preview + Export Report
          Row(
            children: [
              // Generate Preview Button
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: isGenerating ? null : onGeneratePreview,
                  icon: isGenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isGenerating ? "Generating..." : "Generate Preview",
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Export Report Button
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: isExporting ? null : onExportReport,
                  icon: isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF107C41)),
                        )
                      : const Icon(Icons.download_rounded, size: 16, color: Color(0xFF107C41)),
                  label: Text(
                    isExporting ? "Exporting..." : "Export File",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF107C41),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF107C41), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
      ),
    );
  }


  Widget _buildDatePickerTile({
    required BuildContext context,
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPicked,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPicked(d);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('d MMMM yyyy').format(date),
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String id, String label, IconData icon, Color color, bool isDark) {
    final isSelected = selectedFormat == id;

    return Expanded(
      child: GestureDetector(
        onTap: () => onFormatChanged(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 4),
              Text(
                id.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
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

  static IconData _getReportIcon(String id) {
    switch (id) {
      case 'matrix_daily':
        return Icons.today_rounded;
      case 'matrix_weekly':
        return Icons.view_week_rounded;
      case 'matrix_monthly':
        return Icons.calendar_view_month_rounded;
      case 'attendance_summary':
        return Icons.summarize_outlined;
      case 'employee_master':
        return Icons.badge_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _buildDailyDatePickerButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) onDateChanged(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.today_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMMM yyyy').format(selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPickerButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await CustomMonthPickerDialog.show(
          context,
          initialDate: selectedDate,
        );
        if (picked != null) onDateChanged(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(selectedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDropdown(BuildContext context, bool isDark) {
    final weeks = ReportWeekOption.getWeeksOfMonth(selectedDate);
    final currentWeek = selectedWeek ?? (weeks.isNotEmpty ? weeks.first : null);
    final weekOptions = weeks.map((w) {
      return DropdownOption<String>(
        value: w.value,
        label: w.label,
        icon: Icons.view_week_rounded,
      );
    }).toList();

    return CustomDropdownSelector<String>(
      label: "",
      placeholder: "Select Week",
      icon: Icons.view_week_rounded,
      selectedValue: currentWeek?.value ?? (weeks.isNotEmpty ? weeks.first.value : ''),
      options: weekOptions,
      onSelected: (val) {
        if (onWeekChanged != null) {
          final found = weeks.firstWhere((w) => w.value == val, orElse: () => weeks.first);
          onWeekChanged!(found);
        }
      },
    );
  }
}
