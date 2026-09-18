import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/reports/core/report_history_model.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/core/report_service.dart';
import 'package:flutter_application/features/reports/widgets/attendance_matrix_table.dart';
import 'package:flutter_application/features/reports/widgets/report_filter_card.dart';
import 'package:flutter_application/features/reports/widgets/report_history_sheet.dart';
import 'package:flutter_application/features/reports/widgets/report_preview_table.dart';
import 'package:flutter_application/features/reports/widgets/report_stats_banner.dart';

class ReportsTabletPortraitView extends StatefulWidget {
  const ReportsTabletPortraitView({super.key});

  @override
  State<ReportsTabletPortraitView> createState() => _ReportsTabletPortraitViewState();
}

class _ReportsTabletPortraitViewState extends State<ReportsTabletPortraitView> {
  late ReportService _reportService;

  // Filter State
  String _selectedReportType = 'matrix_monthly';
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _useDateRange = false;
  String _selectedDept = 'All Departments';
  List<String> _departments = ['All Departments'];
  String _selectedFormat = 'xlsx';
  String _searchQuery = '';

  // View Mode: 0 = Matrix, 1 = Spreadsheet Table
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

    _loadDepartments();
    _loadData();
    _loadHistory();
  }

  Future<void> _loadDepartments() async {
    final depts = await _reportService.fetchRealDepartments();
    if (mounted && depts.isNotEmpty) {
      final names = depts.map((d) => d['dept_name']?.toString() ?? d['name']?.toString() ?? '').where((n) => n.isNotEmpty).toSet().toList();
      setState(() {
        _departments = ['All Departments', ...names];
      });
    }
  }

  Future<void> _loadHistory() async {
    final list = await _reportService.getDownloadHistory();
    if (mounted) setState(() => _downloadHistory = list);
  }

  Future<void> _loadData() async {
    setState(() => _isGenerating = true);
    try {
      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final result = await _reportService.getPreview(
        type: _selectedReportType,
        month: monthStr,
        date: dateStr,
        deptId: _selectedDept == 'All Departments' ? null : _selectedDept,
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
        context.showToast("Failed to fetch reports preview", isError: true);
      }
    }
  }

  Future<void> _exportFile([String? format]) async {
    final targetFormat = format ?? _selectedFormat;
    setState(() => _isExporting = true);
    try {
      final monthStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}";
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      final path = await _reportService.exportReport(
        type: _selectedReportType,
        format: targetFormat,
        month: monthStr,
        date: dateStr,
        deptId: _selectedDept == 'All Departments' ? null : _selectedDept,
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter Controls ─────────────────────────────────────────
              ReportFilterCard(
                selectedReportType: _selectedReportType,
                onReportTypeChanged: (val) {
                  setState(() => _selectedReportType = val);
                  _loadData();
                },
                selectedDate: _selectedDate,
                onDateChanged: (val) {
                  setState(() => _selectedDate = val);
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
                onToggleDateRange: (v) => setState(() => _useDateRange = v),
                selectedDept: _selectedDept,
                onDeptChanged: (val) {
                  setState(() => _selectedDept = val);
                  _loadData();
                },
                departments: _departments,
                selectedFormat: _selectedFormat,
                onFormatChanged: (val) => setState(() => _selectedFormat = val),
                onGenerate: _loadData,
                onExport: _exportFile,
                onToggleHistory: () => ReportHistorySheet.show(context, _downloadHistory),
                isGenerating: _isGenerating,
                isExporting: _isExporting,
                isCompact: true,
              ),
              const SizedBox(height: 12),

              // ── Summary Metrics 6-Box Row ───────────────────────────────
              if (_previewResult != null) ...[
                ReportStatsBanner(summary: _previewResult!.summary),
                const SizedBox(height: 12),
              ],

              // ── Tab Mode Switcher + Search Bar ──────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton(0, "Attendance Matrix", Icons.calendar_view_month_rounded, isDark),
                        const SizedBox(width: 4),
                        _buildTabButton(1, "Spreadsheet Preview", Icons.table_chart_outlined, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: GoogleFonts.poppins(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: "Search employee, ID, department...",
                          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Data Content ───────────────────────────────────────────
              if (_isGenerating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_previewResult != null)
                _activeViewTab == 0
                    ? AttendanceMatrixTable(
                        key: const ValueKey('matrix_view'),
                        matrix: _previewResult!.matrix,
                        dates: _previewResult!.matrixDates,
                        searchQuery: _searchQuery,
                      )
                    : ReportPreviewTable(
                        key: ValueKey('preview_${_selectedReportType}_${_selectedDate.millisecondsSinceEpoch}'),
                        columns: _previewResult!.columns,
                        rows: _previewResult!.rows,
                        searchQuery: _searchQuery,
                        reportTitle: _selectedReportType,
                        onExportExcel: () => _exportFile('xlsx'),
                        onExportCsv: () => _exportFile('csv'),
                        onExportPdf: () => _exportFile('pdf'),
                        isExporting: _isExporting,
                      )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      "Click Generate to load preview data",
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeViewTab == index;

    return InkWell(
      onTap: () => setState(() => _activeViewTab = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF21262D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [upd:2026-04-27T09:00:00+05:30]

// [rev:2026-08-24T11:00:00+05:30]
