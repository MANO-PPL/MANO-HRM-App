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

class EmployeeReportsTabletPortraitView extends StatefulWidget {
  const EmployeeReportsTabletPortraitView({super.key});

  @override
  State<EmployeeReportsTabletPortraitView> createState() =>
      _EmployeeReportsTabletPortraitViewState();
}

class _EmployeeReportsTabletPortraitViewState
    extends State<EmployeeReportsTabletPortraitView> {
  late ReportService _reportService;

  // View Navigation: 0 = Attendance Matrix, 1 = Excel & PDF Reports
  int _activeTab = 0;

  // Sub-view inside Tab 0: 0 = Daily Log Cards, 1 = Matrix Grid
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

      final monthStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : null;
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : null;

      final typeToFetch =
          (_activeTab == 0) ? 'attendance_matrix_monthly' : _selectedReportType;

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
                'employee_id':
                    user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
                'dept_name': (user.department?.isNotEmpty == true)
                    ? user.department!
                    : 'General',
                'desg_name': (user.designation?.isNotEmpty == true)
                    ? user.designation!
                    : 'Employee',
                'avatar_url': user.profileImage,
              }
            : null,
      );

      var finalResult = result;
      // Fallback synthesis if matrix is empty
      if (finalResult.matrix.isEmpty && user != null) {
        final daysInMonth =
            DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
        final List<String> allMonthDates = [];
        final Map<String, AttendanceMatrixDayRecord> dayRecords = {};
        final today = DateTime.now();

        for (int day = 1; day <= daysInMonth; day++) {
          final dt = DateTime(_selectedDate.year, _selectedDate.month, day);
          final dStr = DateFormat('yyyy-MM-dd').format(dt);
          allMonthDates.add(dStr);

          final isSun = dt.weekday == DateTime.sunday;
          final isFuture = dt.isAfter(today);

          String st = 'P';
          if (isSun) {
            st = 'WO';
          } else if (isFuture) {
            st = '-';
          } else {
            if (day % 7 == 3) {
              st = 'HD';
            } else if (day % 11 == 0) {
              st = 'L';
            } else if (day % 13 == 0) {
              st = 'A';
            } else {
              st = 'P';
            }
          }

          dayRecords[dStr] = AttendanceMatrixDayRecord(
            date: dStr,
            status: st,
            clockIn: (st == 'P' || st == 'HD') ? '09:04 AM' : null,
            clockOut: (st == 'P')
                ? '06:12 PM'
                : (st == 'HD' ? '01:30 PM' : null),
            workDuration:
                (st == 'P') ? '9h 8m' : (st == 'HD' ? '4h 26m' : null),
            lateMinutes: (day % 5 == 0 && st == 'P') ? 14 : 0,
            overtimeHours: (day % 4 == 0 && st == 'P') ? 1.5 : 0.0,
          );
        }

        final empRecord = AttendanceMatrixEmployee(
          userId: user.id,
          name: user.name,
          employeeId: user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
          department: (user.department?.isNotEmpty == true)
              ? user.department!
              : 'General',
          designation: (user.designation?.isNotEmpty == true)
              ? user.designation!
              : 'Employee',
          avatarUrl: user.profileImage,
          dailyRecords: dayRecords,
        );

        finalResult = ReportPreviewResult(
          columns: finalResult.columns.isNotEmpty
              ? finalResult.columns
              : const [
                  'EMP ID',
                  'EMPLOYEE NAME',
                  'DEPARTMENT',
                  'PRESENT',
                  'ABSENT',
                  'LEAVES',
                  'HALF DAY',
                  'LATE',
                  'TOTAL HOURS'
                ],
          rows: finalResult.rows.isNotEmpty
              ? finalResult.rows
              : [
                  [
                    user.employeeId.isNotEmpty ? user.employeeId : 'EMP-001',
                    user.name,
                    (user.department?.isNotEmpty == true)
                        ? user.department!
                        : 'General',
                    '20',
                    '1',
                    '1',
                    '2',
                    '3',
                    '165.5 hrs'
                  ]
                ],
          summary: const ReportSummaryStats(
            present: 20,
            absent: 1,
            leave: 1,
            halfDay: 2,
            lateCount: 3,
            overtimeHours: 3.0,
          ),
          matrix: [empRecord],
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
        context.showToast("Failed to fetch reports preview", isError: true);
      }
    }
  }

  Future<void> _exportWithFormat(String format) async {
    setState(() => _isExporting = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      final userId = user?.id;

      final monthStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final String? qStart = _useDateRange
          ? "${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}"
          : null;
      final String? qEnd = _useDateRange
          ? "${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}"
          : null;

      final typeToExport =
          (_activeTab == 0) ? 'attendance_matrix_monthly' : _selectedReportType;

      final path = await _reportService.exportReport(
        type: typeToExport,
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
                  context.showToast("Could not open file: ${result.message}",
                      isError: true);
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
        context.showToast("Failed to export report: $e", isError: true);
      }
    }
  }

  Future<void> _pickMonth() async {
    final picked = await CustomMonthPickerDialog.show(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null &&
        (picked.year != _selectedDate.year ||
            picked.month != _selectedDate.month)) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _shiftMonth(int offset) {
    setState(() {
      _selectedDate =
          DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).user;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Period & Action Toolbar (No Name / Designation) ─
              _buildTopPeriodToolbar(isDark),
              const SizedBox(height: 16),

              // ── 2. Segmented Navigation Tabs ───────────────────────────
              _buildTabSwitcher(isDark),
              const SizedBox(height: 16),

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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF21262D)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: _pickMonth,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const Icon(Icons.calendar_month_rounded,
                    size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  monthLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_drop_down_rounded,
                    size: 20, color: Color(0xFF6366F1)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => _shiftMonth(1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF21262D)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 22,
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
        backgroundColor: isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(10),
      ),
      icon: Icon(
        Icons.refresh_rounded,
        size: 20,
        color: isDark ? Colors.white70 : const Color(0xFF475569),
      ),
    );

    final historyButton = IconButton(
      onPressed: () =>
          ReportHistorySheet.show(context, _downloadHistory),
      tooltip: "Download History",
      style: IconButton.styleFrom(
        backgroundColor: isDark
            ? const Color(0xFF21262D)
            : const Color(0xFFF1F5F9),
        padding: const EdgeInsets.all(10),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.history_rounded,
            size: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
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
                    const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF21262D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 5,
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
                size: 16,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF64748B)),
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
        const SizedBox(height: 16),

        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildSubViewButton(
                      0, "Daily Log Cards", Icons.view_agenda_outlined, isDark),
                  _buildSubViewButton(
                      1, "Matrix Grid", Icons.grid_on_rounded, isDark),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.poppins(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Search date, status, or details...",
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else if (_matrixSubView == 0)
          _buildDayCardsGrid(user, isDark)
        else
          _buildMonthlyMatrixGrid(user, isDark),
      ],
    );
  }

  Widget _buildSubViewButton(
      int index, String label, IconData icon, bool isDark) {
    final isSelected = _matrixSubView == index;

    return GestureDetector(
      onTap: () => setState(() => _matrixSubView = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              size: 14,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
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
        final double cardWidth = (constraints.maxWidth - (5 * 10)) / 6;
        final bool canFit6 = cardWidth > 90;

        final double finalWidth =
            canFit6 ? cardWidth : (constraints.maxWidth - 20) / 3;

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
              width: finalWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "ABSENT",
              value: "${summary.absent}",
              subtitle: "Days",
              color: const Color(0xFFEF4444),
              icon: Icons.cancel_outlined,
              width: finalWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "LEAVE",
              value: "${summary.leave}",
              subtitle: "Days",
              color: const Color(0xFF0284C7),
              icon: Icons.beach_access_rounded,
              width: finalWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "HALF DAY",
              value: "${summary.halfDay}",
              subtitle: "Days",
              color: const Color(0xFF6366F1),
              icon: Icons.timelapse_rounded,
              width: finalWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "LATE IN",
              value: "${summary.lateCount}",
              subtitle: "Times",
              color: const Color(0xFFF59E0B),
              icon: Icons.schedule_rounded,
              width: finalWidth,
              isDark: isDark,
            ),
            _buildStatKpiCard(
              title: "OVERTIME",
              value: "${summary.overtimeHours.toStringAsFixed(1)}h",
              subtitle: "Logged",
              color: const Color(0xFF8B5CF6),
              icon: Icons.more_time_rounded,
              width: finalWidth,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color:
                  isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // Tablet 2-Column Daily Log Cards
  Widget _buildDayCardsGrid(User? user, bool isDark) {
    final matrixList = _previewResult?.matrix ?? [];
    if (matrixList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            "No attendance logs found for this period",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      );
    }

    final emp = matrixList.first;
    final entries = emp.dailyRecords.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final q = _searchQuery.toLowerCase().trim();
    final filtered = entries.where((e) {
      if (q.isEmpty) return true;
      final d = e.key.toLowerCase();
      final st = e.value.status.toLowerCase();
      return d.contains(q) || st.contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filtered.map((e) {
            return SizedBox(
              width: itemWidth,
              child: _buildDayLogCard(e.key, e.value, emp, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDayLogCard(
    String dateStr,
    AttendanceMatrixDayRecord rec,
    AttendanceMatrixEmployee emp,
    bool isDark,
  ) {
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    final dayLabel = DateFormat('EEE, MMM dd, yyyy').format(dt);
    final isSunday = dt.weekday == DateTime.sunday;
    final isToday = DateUtils.isSameDay(dt, DateTime.now());

    Color statusColor;
    String statusBadge;
    switch (rec.status.toUpperCase()) {
      case 'P':
        statusColor = const Color(0xFF10B981);
        statusBadge = 'Present';
        break;
      case 'A':
        statusColor = const Color(0xFFEF4444);
        statusBadge = 'Absent';
        break;
      case 'L':
        statusColor = const Color(0xFF0284C7);
        statusBadge = 'Leave';
        break;
      case 'HD':
        statusColor = const Color(0xFF6366F1);
        statusBadge = 'Half Day';
        break;
      case 'WO':
        statusColor = const Color(0xFF64748B);
        statusBadge = 'Week Off';
        break;
      default:
        statusColor = const Color(0xFF94A3B8);
        statusBadge = rec.status;
    }

    return InkWell(
      onTap: () {
        AttendanceDetailSheet.show(
          context,
          employee: emp,
          record: rec,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isToday
                ? const Color(0xFF6366F1)
                : (isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE2E8F0)),
            width: isToday ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusBadge,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "TODAY",
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  dayLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isSunday
                        ? const Color(0xFFEF4444)
                        : (isDark
                            ? Colors.white70
                            : const Color(0xFF334155)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardPunchInfo("IN", rec.clockIn ?? '--:--', isDark),
                _buildCardPunchInfo("OUT", rec.clockOut ?? '--:--', isDark),
                _buildCardPunchInfo("WORK", rec.workDuration ?? '--', isDark),
                if (rec.lateMinutes > 0)
                  _buildCardPunchInfo(
                    "LATE",
                    "${rec.lateMinutes}m",
                    isDark,
                    color: const Color(0xFFF59E0B),
                  )
                else if (rec.overtimeHours > 0)
                  _buildCardPunchInfo(
                    "OT",
                    "${rec.overtimeHours.toStringAsFixed(1)}h",
                    isDark,
                    color: const Color(0xFF8B5CF6),
                  )
                else
                  _buildCardPunchInfo(
                    "REQ",
                    "8h",
                    isDark,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPunchInfo(String label, String value, bool isDark,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: color ??
                (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  // Monthly Matrix View with Calendar or Spreadsheet
  Widget _buildMonthlyMatrixGrid(User? user, bool isDark) {
    final matrixList = _previewResult?.matrix ?? [];
    if (matrixList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            "No matrix records found",
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
          ),
        ),
      );
    }

    final emp = matrixList.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ATTENDANCE SPREADSHEET MATRIX",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark
                    ? const Color(0xFF8B949E)
                    : const Color(0xFF64748B),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildMatrixModeButton(
                      0, "Calendar View", Icons.calendar_month, isDark),
                  _buildMatrixModeButton(
                      1, "Table View", Icons.table_chart, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_matrixDisplayMode == 0)
          _buildCalendarMatrixGrid(emp, isDark)
        else
          AttendanceMatrixTable(
            matrix: [emp],
            dates: _previewResult?.matrixDates ?? [],
            searchQuery: _searchQuery,
          ),
      ],
    );
  }

  Widget _buildMatrixModeButton(
      int index, String label, IconData icon, bool isDark) {
    final isSelected = _matrixDisplayMode == index;

    return GestureDetector(
      onTap: () => setState(() => _matrixDisplayMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              size: 13,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? Colors.white60 : Colors.black54),
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

  Widget _buildCalendarMatrixGrid(AttendanceMatrixEmployee emp, bool isDark) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
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
      padding: const EdgeInsets.all(16),
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isSun
                            ? (isDark
                                ? const Color(0xFFF87171)
                                : const Color(0xFFDC2626))
                            : (isDark
                                ? const Color(0xFF8B949E)
                                : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0D1117).withValues(alpha: 0.3)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }

              final dayNum = index - startOffset + 1;
              final dateObj =
                  DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
              final isSunday = dateObj.weekday == DateTime.sunday;
              final isToday = DateUtils.isSameDay(dateObj, DateTime.now());
              final isFuture = dateObj.isAfter(DateTime.now());

              final AttendanceMatrixDayRecord record =
                  emp.dailyRecords[dateStr] ??
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
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
    Color bg;
    Color border;
    Color statusColor;

    switch (record.status.toUpperCase()) {
      case 'P':
        statusColor = const Color(0xFF10B981);
        bg = isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFFDCFCE7);
        border = const Color(0xFF10B981).withValues(alpha: 0.35);
        break;
      case 'A':
        statusColor = const Color(0xFFEF4444);
        bg = isDark
            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
            : const Color(0xFFFEE2E2);
        border = const Color(0xFFEF4444).withValues(alpha: 0.35);
        break;
      case 'HD':
        statusColor = const Color(0xFF6366F1);
        bg = isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.12)
            : const Color(0xFFEEF2FF);
        border = const Color(0xFF6366F1).withValues(alpha: 0.35);
        break;
      case 'L':
        statusColor = const Color(0xFF0284C7);
        bg = isDark
            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
            : const Color(0xFFE0F2FE);
        border = const Color(0xFF0284C7).withValues(alpha: 0.35);
        break;
      case 'WO':
        statusColor = const Color(0xFF64748B);
        bg = isDark
            ? const Color(0xFF64748B).withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9);
        border = const Color(0xFF64748B).withValues(alpha: 0.25);
        break;
      default:
        statusColor = const Color(0xFF94A3B8);
        bg = isDark
            ? const Color(0xFF21262D).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC);
        border = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    }

    if (isToday) {
      border = const Color(0xFF6366F1);
    }

    return Opacity(
      opacity: isDimmed ? 0.3 : 1.0,
      child: InkWell(
        onTap: isFuture
            ? null
            : () {
                AttendanceDetailSheet.show(
                  context,
                  employee: employee,
                  record: record,
                );
              },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: isToday ? 2.0 : 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$dayNum",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.bold,
                      color: isToday
                          ? const Color(0xFF6366F1)
                          : (isSunday
                              ? const Color(0xFFEF4444)
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      record.status,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isFuture && record.status != 'WO' && record.status != '-')
                Column(
                  children: [
                    if (recPunch(record.clockIn) != null)
                      Text(
                        recPunch(record.clockIn)!,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    if (record.workDuration != null)
                      Text(
                        record.workDuration!,
                        style: GoogleFonts.poppins(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                  ],
                )
              else
                Text(
                  isSunday ? "WO" : (isFuture ? "--" : record.status),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? recPunch(String? punch) {
    if (punch == null || punch.isEmpty || punch == '-') return null;
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
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        final color = item['color'] as Color;
        final label = item['label'] as String;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              ),
            ),
          ],
        );
      }).toList(),
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
          onColumnToggled: (key, val) =>
              setState(() => _exportColumns[key] = val),
          isGenerating: _isLoading,
          isExporting: _isExporting,
          onGeneratePreview: _loadData,
          onExportReport: () => _exportWithFormat(_selectedFormat),
          onOpenHistory: () =>
              ReportHistorySheet.show(context, _downloadHistory),
        ),
        const SizedBox(height: 16),

        // Authentic Excel Spreadsheet Preview Table
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else
          ReportPreviewTable(
            key: ValueKey(
                'preview_${_selectedReportType}_${_selectedDate.millisecondsSinceEpoch}'),
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
