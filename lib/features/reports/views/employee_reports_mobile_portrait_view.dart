import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/models/user_model.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/reports/core/report_history_model.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/core/report_service.dart';
import 'package:flutter_application/features/reports/widgets/attendance_detail_sheet.dart';
import 'package:flutter_application/features/reports/widgets/attendance_matrix_table.dart';
import 'package:flutter_application/features/reports/widgets/custom_month_picker_dialog.dart';
import 'package:flutter_application/features/reports/widgets/full_report_filters_panel.dart';
import 'package:flutter_application/features/reports/widgets/report_history_sheet.dart';
import 'package:flutter_application/features/reports/widgets/report_preview_table.dart';

class EmployeeReportsMobilePortraitView extends StatefulWidget {
  const EmployeeReportsMobilePortraitView({super.key});

  @override
  State<EmployeeReportsMobilePortraitView> createState() => _EmployeeReportsMobilePortraitViewState();
}

class _EmployeeReportsMobilePortraitViewState extends State<EmployeeReportsMobilePortraitView> {
  late ReportService _reportService;

  // View Navigation: 0 = Attendance Matrix, 1 = Excel & PDF Reports
  int _activeTab = 0;

  // Sub-view inside Tab 0: 0 = Day Cards, 1 = Matrix Grid
  int _matrixSubView = 0;
  // Matrix display mode: 0 = Calendar Grid, 1 = Spreadsheet Table
  int _matrixDisplayMode = 0;

  // Date and Filter State
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _useDateRange = false;

  // Report Generator Configuration
  String _selectedReportType = 'attendance_detailed';
  String _selectedFormat = 'xlsx';
  String _searchQuery = '';

  // Export Columns Selection
  final Map<String, bool> _exportColumns = {
    'clock_in_out': true,
    'status': true,
    'work_duration': true,
    'required_hours': true,
    'late_minutes': true,
    'location': true,
  };

  // State Management
  ReportPreviewResult? _previewResult;
  bool _isLoading = false;
  bool _isExporting = false;
  List<ReportHistory> _downloadHistory = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _reportService = ReportService(auth.dio);

    _loadData();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await _reportService.getDownloadHistory();
    if (mounted) setState(() => _downloadHistory = list);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      final userId = user?.id;

      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : null;
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : null;

      final typeToFetch = (_activeTab == 0) ? 'attendance_matrix_monthly' : _selectedReportType;

      final result = await _reportService.getPreview(
        type: typeToFetch,
        month: monthStr,
        date: dateStr,
        startDate: qStart,
        endDate: qEnd,
        userId: userId,
        currentUserInfo: user != null
            ? {
                'user_id': user.id,
                'id': user.id,
                'user_name': user.name,
                'name': user.name,
                'employee_id': user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
                'dept_name': (user.department?.isNotEmpty == true) ? user.department! : 'General',
                'desg_name': (user.designation?.isNotEmpty == true) ? user.designation! : 'Employee',
                'avatar_url': user.profileImage,
              }
            : null,
      );

      var finalResult = result;
      // Fallback: If matrix is empty, synthesize the current user's monthly attendance matrix
      if (finalResult.matrix.isEmpty && user != null) {
        final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
        final List<String> allMonthDates = [];
        final Map<String, AttendanceMatrixDayRecord> dayRecords = {};

        for (int day = 1; day <= daysInMonth; day++) {
          final dt = DateTime(_selectedDate.year, _selectedDate.month, day);
          final dStr = DateFormat('yyyy-MM-dd').format(dt);
          allMonthDates.add(dStr);

          final isSun = dt.weekday == DateTime.sunday;
          final isFuture = dt.isAfter(DateTime.now());

          dayRecords[dStr] = AttendanceMatrixDayRecord(
            date: dStr,
            status: isSun ? 'WO' : (isFuture ? '-' : 'A'),
          );
        }

        final synthesizedEmp = AttendanceMatrixEmployee(
          userId: user.id,
          name: user.name,
          employeeId: user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
          department: (user.department?.isNotEmpty == true) ? user.department! : 'General',
          designation: (user.designation?.isNotEmpty == true) ? user.designation! : 'Employee',
          avatarUrl: user.profileImage,
          dailyRecords: dayRecords,
        );

        finalResult = ReportPreviewResult(
          columns: finalResult.columns.isNotEmpty
              ? finalResult.columns
              : ['EMP ID', 'EMPLOYEE NAME', 'DEPARTMENT', 'PRESENT', 'ABSENT', 'LEAVES', 'HALF DAY', 'LATE', 'TOTAL HOURS'],
          rows: finalResult.rows.isNotEmpty
              ? finalResult.rows
              : [
                  [
                    user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
                    user.name,
                    (user.department?.isNotEmpty == true) ? user.department! : 'General',
                    '0',
                    '0',
                    '0',
                    '0',
                    '0',
                    '0.0 hrs'
                  ]
                ],
          summary: finalResult.summary,
          matrix: [synthesizedEmp],
          matrixDates: allMonthDates,
        );
      }

      if (mounted) {
        setState(() {
          _previewResult = finalResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showToast("Failed to load reports data", isError: true);
      }
    }
  }

  Future<void> _exportWithFormat(String format) async {
    setState(() => _isExporting = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      final userId = user?.id;

      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : null;
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : null;

      final path = await _reportService.exportReport(
        type: _selectedReportType,
        format: format,
        month: monthStr,
        date: dateStr,
        startDate: qStart,
        endDate: qEnd,
        userId: userId,
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

  Future<void> _pickMonth() async {
    final picked = await CustomMonthPickerDialog.show(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null && (picked.year != _selectedDate.year || picked.month != _selectedDate.month)) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _shiftMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).user;

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
              // ── 1. Top Period & Action Toolbar (No Name / Designation) ─
              _buildTopPeriodToolbar(isDark),
              const SizedBox(height: 8),

              // ── 2. Segmented Navigation Tabs ───────────────────────────
              _buildTabSwitcher(isDark),
              const SizedBox(height: 8),

              // ── 3. Tab Content ─────────────────────────────────────────
              if (_activeTab == 0)
                _buildAttendanceMatrixTab(user, isDark)
              else
                _buildExcelReportTab(user, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOP PERIOD TOOLBAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTopPeriodToolbar(bool isDark) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedDate);

    final monthFilterWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _shiftMonth(-1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 8),

        InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 7),
                Text(
                  monthLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF6366F1)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        InkWell(
          onTap: () => _shiftMonth(1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );

    final refreshButton = IconButton(
      onPressed: _isLoading ? null : _loadData,
      tooltip: "Refresh Data",
      style: IconButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(8),
      ),
      icon: Icon(
        Icons.refresh_rounded,
        size: 18,
        color: isDark ? Colors.white70 : const Color(0xFF475569),
      ),
    );

    final historyButton = IconButton(
      onPressed: () => ReportHistorySheet.show(context, _downloadHistory),
      tooltip: "Download History",
      style: IconButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(8),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.history_rounded,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
          if (_downloadHistory.isNotEmpty)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                refreshButton,
                Flexible(child: Center(child: monthFilterWidget)),
                historyButton,
              ],
            );
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(child: monthFilterWidget),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    refreshButton,
                    const SizedBox(width: 6),
                    historyButton,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB SWITCHER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTabSwitcher(bool isDark) {
    return Container(
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
          _buildSegmentTab(
            index: 0,
            label: "Attendance Matrix",
            icon: Icons.calendar_view_month_rounded,
            isDark: isDark,
          ),
          _buildSegmentTab(
            index: 1,
            label: "Excel & PDF Reports",
            icon: Icons.table_chart_outlined,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = index);
          if (_previewResult == null) _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 6),
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
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
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

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: ATTENDANCE MATRIX
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAttendanceMatrixTab(User? user, bool isDark) {
    final summary = _previewResult?.summary ?? const ReportSummaryStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryStatsGrid(summary, isDark),
        const SizedBox(height: 14),

        // View Switcher Bar (Daily Log vs Matrix Grid)
        Container(
          width: double.infinity,
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
              Expanded(child: _buildSubViewButton(0, "Daily Log", Icons.view_agenda_outlined, isDark)),
              Expanded(child: _buildSubViewButton(1, "Matrix Grid", Icons.grid_on_rounded, isDark)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Search Field
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.poppins(fontSize: 11.5),
            decoration: InputDecoration(
              hintText: "Search date or status...",
              hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
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
        const SizedBox(height: 12),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else if (_matrixSubView == 0)
          _buildDayCardsList(user, isDark)
        else
          _buildMonthlyMatrixGrid(user, isDark),
      ],
    );
  }

  Widget _buildSubViewButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _matrixSubView == index;

    return GestureDetector(
      onTap: () => setState(() => _matrixSubView = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF21262D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatsGrid(ReportSummaryStats summary, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 20) / 3;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildStatKpiCard(
              title: "PRESENT",
              value: "${summary.present}",
              subtitle: "Days",
              color: const Color(0xFF10B981),
              icon: Icons.check_circle_outline_rounded,
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "ABSENT",
              value: "${summary.absent}",
              subtitle: "Days",
              color: const Color(0xFFEF4444),
              icon: Icons.cancel_outlined,
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "LEAVE",
              value: "${summary.leave}",
              subtitle: "Days",
              color: const Color(0xFF0284C7),
              icon: Icons.beach_access_rounded,
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "HALF DAY",
              value: "${summary.halfDay}",
              subtitle: "Days",
              color: const Color(0xFF6366F1),
              icon: Icons.timelapse_rounded,
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "LATE IN",
              value: "${summary.lateCount}",
              subtitle: "Times",
              color: const Color(0xFFF59E0B),
              icon: Icons.schedule_rounded,
              width: cardWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "OVERTIME",
              value: "${summary.overtimeHours.toStringAsFixed(1)}h",
              subtitle: "Hours",
              color: const Color(0xFF8B5CF6),
              icon: Icons.more_time_rounded,
              width: cardWidth,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required double width,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DAY CARDS LIST
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDayCardsList(User? user, bool isDark) {
    final matrix = _previewResult?.matrix ?? [];
    final emp = matrix.isNotEmpty
        ? matrix.firstWhere(
            (e) => e.userId == user?.id,
            orElse: () => matrix.first,
          )
        : AttendanceMatrixEmployee(
            userId: user?.id ?? '',
            name: user?.name ?? 'Employee',
            employeeId: user?.employeeId ?? 'EMP-001',
            department: (user?.department?.isNotEmpty == true) ? user!.department! : 'General',
            designation: (user?.designation?.isNotEmpty == true) ? user!.designation! : 'Staff',
            dailyRecords: {},
          );

    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final List<Map<String, dynamic>> dayItems = [];
    final q = _searchQuery.toLowerCase().trim();

    for (int day = 1; day <= daysInMonth; day++) {
      final dateObj = DateTime(_selectedDate.year, _selectedDate.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
      final dayRecord = emp.dailyRecords[dateStr];

      final dayOfWeek = DateFormat('EEE').format(dateObj);
      final dayName = DateFormat('EEEE').format(dateObj);
      final isSunday = dateObj.weekday == DateTime.sunday;

      String status = dayRecord?.status ?? (isSunday ? 'WO' : '-');
      if (dateObj.isAfter(DateTime.now()) && dayRecord == null) {
        status = isSunday ? 'WO' : '-';
      }

      if (q.isNotEmpty) {
        final matches = dateStr.contains(q) ||
            dayName.toLowerCase().contains(q) ||
            dayOfWeek.toLowerCase().contains(q) ||
            status.toLowerCase().contains(q);
        if (!matches) continue;
      }

      dayItems.add({
        'day': day,
        'date': dateObj,
        'dateStr': dateStr,
        'record': dayRecord ??
            AttendanceMatrixDayRecord(
              date: dateStr,
              status: status,
              clockIn: null,
              clockOut: null,
              workDuration: null,
            ),
        'isSunday': isSunday,
      });
    }

    if (dayItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined, size: 36, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                "No records found for the search query",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dayItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = dayItems[index];
        final DateTime d = item['date'];
        final AttendanceMatrixDayRecord record = item['record'];
        final bool isSunday = item['isSunday'];

        return _buildDayCard(
          employee: emp,
          record: record,
          date: d,
          isSunday: isSunday,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildDayCard({
    required AttendanceMatrixEmployee employee,
    required AttendanceMatrixDayRecord record,
    required DateTime date,
    required bool isSunday,
    required bool isDark,
  }) {
    final statusColor = record.statusColor;
    final hasPunches = record.clockIn != null && record.clockIn!.isNotEmpty && record.clockIn != '-';
    final hasClockOut = record.clockOut != null && record.clockOut!.isNotEmpty && record.clockOut != '-';
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => AttendanceDetailSheet.show(context, employee: employee, record: record),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Day Badge
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        date.day.toString().padLeft(2, '0'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Middle: Timings, Duration, Late & Overtime
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatStatusLabel(record.status),
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          if (record.workDuration != null && record.workDuration!.isNotEmpty)
                            Text(
                              "Duration: ${record.workDuration}",
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            )
                          else if (isSunday)
                            Text(
                              "Weekend Off",
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      if (hasPunches)
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              "${record.clockIn} → ${hasClockOut ? record.clockOut : 'In Progress'}",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          date.isAfter(DateTime.now()) ? "Upcoming" : "No punches recorded",
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),

                      if (record.isLate || record.overtimeHours > 0 || (record.inLocation != null && record.inLocation!.isNotEmpty)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (record.isLate)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Late: ${record.lateMinutes}m",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            if (record.overtimeHours > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "OT: ${record.overtimeHours}h",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStatusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'P':
      case 'PRESENT':
        return 'PRESENT';
      case 'A':
      case 'ABSENT':
        return 'ABSENT';
      case 'L':
      case 'LEAVE':
        return 'ON LEAVE';
      case 'HD':
      case 'HALF_DAY':
        return 'HALF DAY';
      case 'WO':
      case 'WEEK_OFF':
        return 'WEEK OFF';
      case 'H':
      case 'HOLIDAY':
        return 'HOLIDAY';
      default:
        return s.isEmpty ? '-' : s.toUpperCase();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MONTHLY MATRIX GRID
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMonthlyMatrixGrid(User? user, bool isDark) {
    final matrix = _previewResult?.matrix ?? [];
    final emp = matrix.isNotEmpty
        ? matrix.firstWhere(
            (e) => e.userId == user?.id,
            orElse: () => matrix.first,
          )
        : AttendanceMatrixEmployee(
            userId: user?.id ?? '',
            name: user?.name ?? 'Employee',
            employeeId: user?.employeeId ?? 'EMP-001',
            department: (user?.department?.isNotEmpty == true) ? user!.department! : 'General',
            designation: (user?.designation?.isNotEmpty == true) ? user!.designation! : 'Staff',
            dailyRecords: {},
          );

    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final List<String> matrixDates = (_previewResult != null && _previewResult!.matrixDates.isNotEmpty)
        ? _previewResult!.matrixDates
        : List.generate(daysInMonth, (i) {
            final d = i + 1;
            return "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
          });

    final matrixToUse = matrix.isNotEmpty ? matrix : [emp];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _matrixDisplayMode == 0 ? "Monthly Calendar Matrix" : "Matrix Spreadsheet View",
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildMatrixModeButton(0, "Calendar", Icons.calendar_view_month_rounded, isDark),
                  _buildMatrixModeButton(1, "Table", Icons.table_chart_outlined, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_matrixDisplayMode == 0)
          _buildCalendarMatrixGrid(emp, isDark)
        else
          AttendanceMatrixTable(
            key: ValueKey("emp_matrix_${_selectedDate.year}_${_selectedDate.month}_${matrixToUse.length}"),
            matrix: matrixToUse,
            dates: matrixDates,
            searchQuery: _searchQuery,
          ),
      ],
    );
  }

  Widget _buildCalendarMatrixGrid(AttendanceMatrixEmployee emp, bool isDark) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;

    final q = _searchQuery.toLowerCase().trim();
    final weekdays = const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: weekdays.map((w) {
              final isSun = w == 'SUN';
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      w,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isSun
                            ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                            : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 0.70,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }

              final dayNum = index - startOffset + 1;
              final dateObj = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
              final isSunday = dateObj.weekday == DateTime.sunday;
              final isToday = DateUtils.isSameDay(dateObj, DateTime.now());
              final isFuture = dateObj.isAfter(DateTime.now());

              final AttendanceMatrixDayRecord record = emp.dailyRecords[dateStr] ??
                  AttendanceMatrixDayRecord(
                    date: dateStr,
                    status: isSunday ? 'WO' : (isFuture ? '-' : 'A'),
                  );

              bool isDimmed = false;
              if (q.isNotEmpty) {
                final statusStr = record.status.toLowerCase();
                final dStrMatch = dateStr.contains(q);
                final statusMatch = statusStr.contains(q);
                if (!dStrMatch && !statusMatch) {
                  isDimmed = true;
                }
              }

              return _buildCalendarDayTile(
                dayNum: dayNum,
                date: dateObj,
                record: record,
                employee: emp,
                isToday: isToday,
                isSunday: isSunday,
                isFuture: isFuture,
                isDimmed: isDimmed,
                isDark: isDark,
              );
            },
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          _buildStatusLegendBar(isDark),
        ],
      ),
    );
  }

  Widget _buildCalendarDayTile({
    required int dayNum,
    required DateTime date,
    required AttendanceMatrixDayRecord record,
    required AttendanceMatrixEmployee employee,
    required bool isToday,
    required bool isSunday,
    required bool isFuture,
    required bool isDimmed,
    required bool isDark,
  }) {
    final statusColor = record.statusColor;
    final hasPunches = record.clockIn != null &&
        record.clockIn!.isNotEmpty &&
        record.clockIn != '-';

    return Opacity(
      opacity: isDimmed ? 0.3 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AttendanceDetailSheet.show(context, employee: employee, record: record);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            decoration: BoxDecoration(
              color: isToday
                  ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                  : (isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday
                    ? const Color(0xFF6366F1)
                    : (record.status == 'P' || record.status == 'PRESENT'
                        ? const Color(0xFF10B981).withValues(alpha: 0.35)
                        : (record.status == 'A' || record.status == 'ABSENT'
                            ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                            : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)))),
                width: isToday ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayNum.toString().padLeft(2, '0'),
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? const Color(0xFF6366F1)
                            : (isSunday
                                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                : (isDark ? Colors.white : const Color(0xFF0F172A))),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.shortStatus,
                        style: GoogleFonts.poppins(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: Center(
                    child: hasPunches
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatTilePunch(record.clockIn),
                                style: GoogleFonts.poppins(
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (record.clockOut != null && record.clockOut!.isNotEmpty && record.clockOut != '-') ...[
                                Text(
                                  _formatTilePunch(record.clockOut),
                                  style: GoogleFonts.poppins(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          )
                        : Text(
                            isSunday
                                ? "OFF"
                                : (record.status == 'H'
                                    ? "HOL"
                                    : (record.status == 'L'
                                        ? "LEAVE"
                                        : (isFuture ? "-" : (record.status == 'A' ? "ABSENT" : "-")))),
                            style: GoogleFonts.poppins(
                              fontSize: 7,
                              fontWeight: FontWeight.w600,
                              color: isSunday
                                  ? (isDark ? Colors.white38 : Colors.black38)
                                  : statusColor.withValues(alpha: 0.8),
                            ),
                          ),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (record.isLate)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (record.overtimeHours > 0)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (!record.isLate && record.overtimeHours <= 0)
                      const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTilePunch(String? punch) {
    if (punch == null || punch.isEmpty || punch == '-') return '';
    return punch.replaceAll(' ', '');
  }

  Widget _buildStatusLegendBar(bool isDark) {
    final items = const [
      {'label': 'P Present', 'color': Color(0xFF10B981)},
      {'label': 'A Absent', 'color': Color(0xFFEF4444)},
      {'label': 'L Leave', 'color': Color(0xFF0284C7)},
      {'label': 'HD Half Day', 'color': Color(0xFF6366F1)},
      {'label': 'WO Week Off', 'color': Color(0xFF64748B)},
      {'label': 'H Holiday', 'color': Color(0xFFF59E0B)},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: items.map((item) {
        final color = item['color'] as Color;
        final label = item['label'] as String;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMatrixModeButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _matrixDisplayMode == index;

    return GestureDetector(
      onTap: () => setState(() => _matrixDisplayMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF21262D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: EXCEL & PDF REPORTS (FULL FILTERS PANEL + EXCEL SPREADSHEET)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildExcelReportTab(User? user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Filters Panel matching Attendance-Web
        FullReportFiltersPanel(
          isEmployee: true,
          selectedReportType: _selectedReportType,
          onReportTypeChanged: (val) {
            setState(() => _selectedReportType = val);
            _loadData();
          },
          selectedDate: _selectedDate,
          onDateChanged: (d) {
            setState(() => _selectedDate = d);
            _loadData();
          },
          useCustomDateRange: _useDateRange,
          onUseCustomRangeChanged: (val) {
            setState(() => _useDateRange = val);
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
          selectedFormat: _selectedFormat,
          onFormatChanged: (f) => setState(() => _selectedFormat = f),
          exportColumns: _exportColumns,
          onColumnToggled: (key, val) => setState(() => _exportColumns[key] = val),
          isGenerating: _isLoading,
          isExporting: _isExporting,
          onGeneratePreview: _loadData,
          onExportReport: () => _exportWithFormat(_selectedFormat),
          onOpenHistory: () => ReportHistorySheet.show(context, _downloadHistory),
        ),
        const SizedBox(height: 14),

        // Authentic Excel Spreadsheet Preview Table
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else
          ReportPreviewTable(
            key: ValueKey('preview_${_selectedReportType}_${_selectedDate.millisecondsSinceEpoch}'),
            columns: _previewResult?.columns ?? const [],
            rows: _previewResult?.rows ?? const [],
            searchQuery: _searchQuery,
            reportTitle: _selectedReportType,
            onExportExcel: () => _exportWithFormat('xlsx'),
            onExportCsv: () => _exportWithFormat('csv'),
            onExportPdf: () => _exportWithFormat('pdf'),
            isExporting: _isExporting,
          ),
      ],
    );
  }
}
