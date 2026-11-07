import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/reports/core/report_history_model.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/core/report_service.dart';
import 'package:flutter_application/features/reports/widgets/attendance_matrix_table.dart';
import 'package:flutter_application/features/reports/widgets/employee_master_preview_table.dart';
import 'package:flutter_application/features/reports/widgets/employee_report_card.dart';
import 'package:flutter_application/features/reports/widgets/muster_roll_table.dart';
import 'package:flutter_application/features/reports/widgets/report_filter_card.dart';
import 'package:flutter_application/features/reports/widgets/report_history_sheet.dart';
import 'package:flutter_application/features/reports/widgets/report_preview_table.dart';

class ReportsMobileView extends StatefulWidget {
  const ReportsMobileView({super.key});

  @override
  State<ReportsMobileView> createState() => _ReportsMobileViewState();
}

class _ReportsMobileViewState extends State<ReportsMobileView> {
  late ReportService _reportService;

  // Filter State
  String _selectedReportType = 'matrix_monthly';
  DateTime _selectedDate = DateTime.now();
  ReportWeekOption? _selectedWeek;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _useDateRange = false;

  String _selectedDept = 'All Departments';
  String? _selectedDeptId;
  List<String> _departments = ['All Departments'];
  List<Map<String, dynamic>> _rawDepartments = [];

  String _selectedDesg = 'All Designations';
  String? _selectedDesgId;
  List<String> _designations = ['All Designations'];
  List<Map<String, dynamic>> _rawDesignations = [];

  String _selectedShift = 'All Shifts';
  String? _selectedShiftId;
  List<String> _shifts = ['All Shifts'];
  List<Map<String, dynamic>> _rawShifts = [];

  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _employees = [];

  String _selectedFormat = 'xlsx';
  String _searchQuery = '';

  Map<String, bool> _exportColumns = {
    'position': true,
    'workedHours': true,
    'timeIn': true,
    'timeOut': true,
    'employeeCode': true,
    'daysInMonth': true,
    'presentDays': true,
    'shift': true,
    'status': true,
    'requiredHours': false,
    'late': false,
    'location': false,
    'attendanceDays': true,
  };

  // View Mode: 0 = Matrix / Card, 1 = Spreadsheet Table
  int _activeViewTab = 0;

  // Data State
  ReportPreviewResult? _previewResult;
  bool _isGenerating = false;
  bool _isExporting = false;
  List<ReportHistory> _downloadHistory = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _reportService = ReportService(auth.dio);

    final weeks = ReportWeekOption.getWeeksOfMonth(_selectedDate);
    if (weeks.isNotEmpty) {
      _selectedWeek = weeks.first;
    }

    _loadMetadata();
    _loadData();
    _loadHistory();
  }

  Future<void> _loadMetadata() async {
    final results = await Future.wait([
      _reportService.fetchRealDepartments(),
      _reportService.fetchRealDesignations(),
      _reportService.fetchRealShifts(),
      _reportService.fetchRealEmployees(),
    ]);

    if (!mounted) return;

    final depts = results[0];
    final desgs = results[1];
    final shfts = results[2];
    final emps = results[3];

    setState(() {
      _rawDepartments = depts;
      _rawDesignations = desgs;
      _rawShifts = shfts;

      if (depts.isNotEmpty) {
        final names = depts
            .map((d) => d['dept_name']?.toString() ?? d['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        _departments = ['All Departments', ...names];
      }

      if (desgs.isNotEmpty) {
        final names = desgs
            .map((d) => d['desg_name']?.toString() ?? d['name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        _designations = ['All Designations', ...names];
      }

      if (shfts.isNotEmpty) {
        final names = shfts
            .map((s) => s['name']?.toString() ?? s['shift_name']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        _shifts = ['All Shifts', ...names];
      }

      if (emps.isNotEmpty) {
        _employees = emps;
      }
    });
  }

  Future<void> _loadHistory() async {
    final list = await _reportService.getDownloadHistory();
    if (mounted) setState(() => _downloadHistory = list);
  }

  Future<void> _loadData() async {
    setState(() => _isGenerating = true);
    try {
      final weeks = ReportWeekOption.getWeeksOfMonth(_selectedDate);
      if (_selectedWeek == null || !weeks.any((w) => w.value == _selectedWeek!.value)) {
        _selectedWeek = weeks.isNotEmpty ? weeks.first : null;
      }

      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final isWeekly = _selectedReportType == 'matrix_weekly';
      final String dateToUse = (isWeekly && !_useDateRange && _selectedWeek != null)
          ? _selectedWeek!.value
          : dateStr;
      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : (isWeekly && _selectedWeek != null ? DateFormat('yyyy-MM-dd').format(_selectedWeek!.start) : null);
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : (isWeekly && _selectedWeek != null ? DateFormat('yyyy-MM-dd').format(_selectedWeek!.end) : null);

      // Pass columns: null so backend returns full dataset for preview table matching Web
      final result = await _reportService.getPreview(
        type: _selectedReportType,
        month: monthStr,
        date: dateToUse,
        startDate: qStart,
        endDate: qEnd,
        userId: _selectedEmployeeId,
        deptId: _selectedDeptId,
        desgId: _selectedDesgId,
        shiftId: _selectedShiftId,
        columns: null,
      );

      if (mounted) {
        setState(() {
          _previewResult = result;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        context.showToast("Failed to fetch reports preview: $e", isError: true);
      }
    }
  }

  Future<void> _exportFile([String? format]) async {
    final targetFormat = format ?? _selectedFormat;
    setState(() => _isExporting = true);
    try {
      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final isWeekly = _selectedReportType == 'matrix_weekly';
      final String dateToUse = (isWeekly && !_useDateRange && _selectedWeek != null)
          ? _selectedWeek!.value
          : dateStr;
      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : (isWeekly && _selectedWeek != null ? DateFormat('yyyy-MM-dd').format(_selectedWeek!.start) : null);
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : (isWeekly && _selectedWeek != null ? DateFormat('yyyy-MM-dd').format(_selectedWeek!.end) : null);

      final path = await _reportService.exportReport(
        type: _selectedReportType,
        format: targetFormat,
        month: monthStr,
        date: dateToUse,
        startDate: qStart,
        endDate: qEnd,
        userId: _selectedEmployeeId,
        deptId: _selectedDeptId,
        desgId: _selectedDesgId,
        shiftId: _selectedShiftId,
        columns: _exportColumns,
      );

      if (mounted) {
        setState(() => _isExporting = false);
        _loadHistory();
        if (path != null) {
          final fileName = path.split(RegExp(r'[\\/]')).last;
          context.showToast(
            "Report exported: $fileName",
            isSuccess: true,
            actionLabel: "OPEN",
            duration: const Duration(seconds: 7),
            onActionPressed: () async {
              try {
                final result = await OpenFilex.open(path);
                if (result.type != ResultType.done && mounted) {
                  context.showToast("Could not open file: ${result.message}", isError: true);
                }
              } catch (e) {
                if (mounted) {
                  context.showToast("Error opening file: $e", isError: true);
                }
              }
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        context.showToast("Export failed: $e", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    AttendanceMatrixEmployee? singleEmp;
    if (_selectedEmployeeId != null &&
        _selectedEmployeeId!.isNotEmpty &&
        _previewResult != null &&
        _previewResult!.matrix.isNotEmpty) {
      singleEmp = _previewResult!.matrix.firstWhere(
        (e) => e.userId == _selectedEmployeeId,
        orElse: () => _previewResult!.matrix.first,
      );
    }

    String dateSubtitle = DateFormat('MMMM yyyy').format(_selectedDate);
    if (_selectedReportType == 'matrix_daily') {
      dateSubtitle = DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate);
    } else if (_selectedReportType == 'matrix_weekly') {
      dateSubtitle = _selectedWeek?.label ?? "${DateFormat('MMM yyyy').format(_selectedDate)} (Weekly)";
    }

    // Filter employees dynamically by selected department, designation, and shift (identical to Web)
    final filteredEmployees = _employees.where((emp) {
      final dId = (emp['dept_id'] ?? emp['department_id'])?.toString();
      final dsId = (emp['desg_id'] ?? emp['designation_id'])?.toString();
      final sId = (emp['shift_id'])?.toString();

      if (_selectedDeptId != null && _selectedDeptId!.isNotEmpty && dId != _selectedDeptId) return false;
      if (_selectedDesgId != null && _selectedDesgId!.isNotEmpty && dsId != _selectedDesgId) return false;
      if (_selectedShiftId != null && _selectedShiftId!.isNotEmpty && sId != _selectedShiftId) return false;
      return true;
    }).toList();

    final double previewHeight = (MediaQuery.of(context).size.height - 180).clamp(500.0, 850.0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter Controls ─────────────────────────────────────────
              ReportFilterCard(
                selectedReportType: _selectedReportType,
                selectedWeek: _selectedWeek,
                onWeekChanged: (w) {
                  setState(() => _selectedWeek = w);
                  _loadData();
                },
                onReportTypeChanged: (val) {
                  setState(() {
                    _selectedReportType = val;
                    if (val == 'matrix_weekly') {
                      final weeks = ReportWeekOption.getWeeksOfMonth(_selectedDate);
                      if (weeks.isNotEmpty) _selectedWeek = weeks.first;
                    }
                  });
                  _loadData();
                },
                selectedDate: _selectedDate,
                onDateChanged: (val) {
                  setState(() {
                    _selectedDate = val;
                    final weeks = ReportWeekOption.getWeeksOfMonth(val);
                    if (weeks.isNotEmpty) {
                      _selectedWeek = weeks.first;
                    }
                  });
                  _loadData();
                },
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeChanged: (s, e) {
                  setState(() {
                    _startDate = s;
                    _endDate = e;
                  });
                  _loadData();
                },
                useDateRange: _useDateRange,
                onToggleDateRange: (v) {
                  setState(() => _useDateRange = v);
                  _loadData();
                },
                selectedDept: _selectedDept,
                onDeptChanged: (val) {
                  setState(() {
                    _selectedDept = val;
                    if (val == 'All Departments') {
                      _selectedDeptId = null;
                    } else {
                      final match = _rawDepartments.firstWhere(
                        (d) => (d['dept_name'] ?? d['name'])?.toString() == val,
                        orElse: () => {},
                      );
                      _selectedDeptId = (match['dept_id'] ?? match['id'])?.toString();
                    }
                    if (_selectedEmployeeId != null &&
                        !filteredEmployees.any((e) => (e['user_id'] ?? e['id'])?.toString() == _selectedEmployeeId)) {
                      _selectedEmployeeId = null;
                    }
                  });
                  _loadData();
                },
                departments: _departments,
                selectedDesg: _selectedDesg,
                onDesgChanged: (val) {
                  setState(() {
                    _selectedDesg = val;
                    if (val == 'All Designations') {
                      _selectedDesgId = null;
                    } else {
                      final match = _rawDesignations.firstWhere(
                        (d) => (d['desg_name'] ?? d['name'])?.toString() == val,
                        orElse: () => {},
                      );
                      _selectedDesgId = (match['desg_id'] ?? match['id'])?.toString();
                    }
                    if (_selectedEmployeeId != null &&
                        !filteredEmployees.any((e) => (e['user_id'] ?? e['id'])?.toString() == _selectedEmployeeId)) {
                      _selectedEmployeeId = null;
                    }
                  });
                  _loadData();
                },
                designations: _designations,
                selectedShift: _selectedShift,
                onShiftChanged: (val) {
                  setState(() {
                    _selectedShift = val;
                    if (val == 'All Shifts') {
                      _selectedShiftId = null;
                    } else {
                      final match = _rawShifts.firstWhere(
                        (s) => (s['name'] ?? s['shift_name'])?.toString() == val,
                        orElse: () => {},
                      );
                      _selectedShiftId = (match['shift_id'] ?? match['id'])?.toString();
                    }
                    if (_selectedEmployeeId != null &&
                        !filteredEmployees.any((e) => (e['user_id'] ?? e['id'])?.toString() == _selectedEmployeeId)) {
                      _selectedEmployeeId = null;
                    }
                  });
                  _loadData();
                },
                shifts: _shifts,
                selectedEmployeeId: _selectedEmployeeId,
                onEmployeeChanged: (val) {
                  setState(() => _selectedEmployeeId = val);
                  _loadData();
                },
                employees: filteredEmployees,
                selectedFormat: _selectedFormat,
                onFormatChanged: (val) => setState(() => _selectedFormat = val),
                exportColumns: _exportColumns,
                onColumnToggled: (key, val) => setState(() {
                  _exportColumns = Map<String, bool>.from(_exportColumns)..[key] = val;
                }),
                onGenerate: _loadData,
                onExport: _exportFile,
                onToggleHistory: () => ReportHistorySheet.show(context, _downloadHistory),
                isGenerating: _isGenerating,
                isExporting: _isExporting,
                isCompact: true,
              ),
              const SizedBox(height: 6),

              // ── View Mode Switcher + Search ────────────────────────────
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabPill(0, "Attendance Matrix", Icons.calendar_view_month_rounded, isDark),
                    _buildTabPill(1, "Preview Table", Icons.table_chart_outlined, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 5),

              // Search Filter Bar
              Container(
                height: 35,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.poppins(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: "Search employee, ID or code...",
                    hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, size: 15),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () => setState(() => _searchQuery = ''),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 5),

              // ── Data View ──────────────────────────────────────────────
              if (_isGenerating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_previewResult != null)
                SizedBox(
                  height: previewHeight,
                  child: _activeViewTab == 0
                      ? (singleEmp != null
                          ? SingleChildScrollView(
                              child: EmployeeReportCard(
                                employee: singleEmp,
                                dates: _previewResult!.matrixDates,
                              ),
                            )
                          : AttendanceMatrixTable(
                              key: const ValueKey('matrix_view'),
                              matrix: _previewResult!.matrix,
                              dates: _previewResult!.matrixDates,
                              searchQuery: _searchQuery,
                            ))
                      : (_selectedReportType == 'employee_master'
                          ? EmployeeMasterPreviewTable(
                              columns: _previewResult!.columns,
                              rows: _previewResult!.rows,
                              searchQuery: _searchQuery,
                              onExportExcel: () => _exportFile('xlsx'),
                              onExportCsv: () => _exportFile('csv'),
                              onExportPdf: () => _exportFile('pdf'),
                              isExporting: _isExporting,
                            )
                          : (_previewResult!.musterRoll != null
                              ? MusterRollTable(
                                  musterRoll: _previewResult!.musterRoll!,
                                  searchQuery: _searchQuery,
                                  onExportExcel: () => _exportFile('xlsx'),
                                  onExportCsv: () => _exportFile('csv'),
                                  onExportPdf: () => _exportFile('pdf'),
                                  isExporting: _isExporting,
                                )
                              : ReportPreviewTable(
                                  key: ValueKey(
                                      'preview_${_selectedReportType}_${_selectedDate.millisecondsSinceEpoch}_${_selectedWeek?.value}'),
                                  columns: _previewResult!.columns,
                                  rows: _previewResult!.rows,
                                  columnsConfig: _exportColumns,
                                  searchQuery: _searchQuery,
                                  reportTitle: _selectedReportType,
                                  dateSubtitle: dateSubtitle,
                                  selectedReportType: _selectedReportType,
                                  selectedWeek: _selectedWeek,
                                  availableWeeks: ReportWeekOption.getWeeksOfMonth(_selectedDate),
                                  onWeekChanged: (w) {
                                    setState(() => _selectedWeek = w);
                                    _loadData();
                                  },
                                  onExportExcel: () => _exportFile('xlsx'),
                                  onExportCsv: () => _exportFile('csv'),
                                  onExportPdf: () => _exportFile('pdf'),
                                  isExporting: _isExporting,
                                ))),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      "Click Generate to load preview data",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeViewTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeViewTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 5.5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF21262D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
