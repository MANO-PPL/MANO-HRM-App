import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';

enum PreviewCellType {
  normal,
  present,
  absent,
  missedPunch,
  halfDay,
  leave,
  late,
  overtime,
  weekOff,
  holiday,
  currency,
}

class _ProcessedPreviewCell {
  final String text;
  final PreviewCellType type;
  final bool isText;

  const _ProcessedPreviewCell({
    required this.text,
    required this.type,
    required this.isText,
  });
}

class ReportPreviewTable extends StatefulWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final Map<String, bool>? columnsConfig;
  final String searchQuery;
  final String? reportTitle;
  final String? dateSubtitle;
  final String? selectedReportType;
  final ReportWeekOption? selectedWeek;
  final List<ReportWeekOption>? availableWeeks;
  final ValueChanged<ReportWeekOption>? onWeekChanged;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportPdf;
  final bool isExporting;

  const ReportPreviewTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnsConfig,
    this.searchQuery = '',
    this.reportTitle,
    this.dateSubtitle,
    this.selectedReportType,
    this.selectedWeek,
    this.availableWeeks,
    this.onWeekChanged,
    this.onExportExcel,
    this.onExportCsv,
    this.onExportPdf,
    this.isExporting = false,
  });

  @override
  State<ReportPreviewTable> createState() => _ReportPreviewTableState();
}

class _ReportPreviewTableState extends State<ReportPreviewTable> {
  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _localSearchController = TextEditingController();
  String _effectiveSearch = '';
  List<List<_ProcessedPreviewCell>> _processedRows = [];
  List<int> _visibleIndices = [];

  // Pagination State: default to -1 (All rows) to show complete dataset
  int _currentPage = 1;
  int _pageSize = -1;

  @override
  void initState() {
    super.initState();
    _effectiveSearch = widget.searchQuery;
    _localSearchController.text = widget.searchQuery;
    _precomputeRows();
  }

  @override
  void didUpdateWidget(covariant ReportPreviewTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(widget.columnsConfig, oldWidget.columnsConfig) ||
        widget.columns != oldWidget.columns ||
        widget.rows != oldWidget.rows ||
        widget.searchQuery != oldWidget.searchQuery) {
      if (widget.searchQuery != oldWidget.searchQuery) {
        _effectiveSearch = widget.searchQuery;
        _localSearchController.text = widget.searchQuery;
      }
      _precomputeRows();
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _localSearchController.dispose();
    super.dispose();
  }

  String? _matchColumnToKey(String header) {
    final h = header.toLowerCase().trim();

    if (h == 'time in' ||
        h == 'in punch' ||
        h == 'clock in' ||
        h == 'in' ||
        h.contains('time in') ||
        h.contains('clock_in')) {
      return 'timeIn';
    }
    if (h == 'time out' ||
        h == 'out punch' ||
        h == 'clock out' ||
        h == 'out' ||
        h.contains('time out') ||
        h.contains('clock_out')) {
      return 'timeOut';
    }
    if (h == 'shift' || h.contains('shift')) {
      return 'shift';
    }
    if (h == 'status' || h == 'attendance status' || h.contains('status')) {
      return 'status';
    }
    if (h == 'work hours' ||
        h == 'worked hours' ||
        h == 'work hr' ||
        h == 'worked' ||
        h == 'total hours' ||
        h.contains('work_duration') ||
        h.contains('worked') ||
        h.contains('shortfall') ||
        h.contains('excess')) {
      return 'workedHours';
    }
    if (h == 'required hours' ||
        h == 'req hr' ||
        h == 'required' ||
        h.contains('required_hours') ||
        h.contains('expected hours')) {
      return 'requiredHours';
    }
    if (h == 'late' ||
        h == 'late in' ||
        h == 'lateness' ||
        h == 'late count' ||
        h == 'late days' ||
        h.contains('late_minutes') ||
        h.contains('lateness') ||
        h.contains('late')) {
      return 'late';
    }
    if (h == 'location' || h == 'branch' || h.contains('location')) {
      return 'location';
    }
    if (h == 'emp id' ||
        h == 'code' ||
        h == 'emp code' ||
        h == 'employee code' ||
        h == 'emp_id') {
      return 'employeeCode';
    }
    if (h == 'designation' || h == 'position' || h == 'role') {
      return 'position';
    }
    if (h == 'days in month' || h == 'total days') {
      return 'daysInMonth';
    }
    if (h == 'present days') {
      return 'presentDays';
    }
    if (h == 'present' ||
        h == 'absent' ||
        h == 'half day' ||
        h == 'half_day' ||
        h == 'leaves' ||
        h == 'on leave' ||
        h == 'holiday' ||
        h == 'attendance' ||
        h.contains('attendance summary')) {
      return 'attendanceDays';
    }

    return null;
  }

  bool _isColumnVisible(String header) {
    final cfg = widget.columnsConfig;
    if (cfg == null || cfg.isEmpty) return true;

    final key = _matchColumnToKey(header);
    if (key == null) return true;

    if (cfg.containsKey(key) && cfg[key] == false) {
      return false;
    }

    if (key == 'timeIn' || key == 'timeOut') {
      if (cfg['clock_in_out'] == false) return false;
    }
    if (key == 'workedHours' && cfg['work_duration'] == false) {
      return false;
    }
    if (key == 'late' && cfg['late_minutes'] == false) {
      return false;
    }

    return true;
  }

  List<int> _computeVisibleIndices() {
    final List<int> indices = [];
    for (int i = 0; i < widget.columns.length; i++) {
      if (_isColumnVisible(widget.columns[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  void _precomputeRows() {
    final q = _effectiveSearch.toLowerCase().trim();

    final filtered = widget.rows.where((row) {
      if (q.isEmpty) return true;
      return row.any((cell) => cell?.toString().toLowerCase().contains(q) == true);
    }).toList();

    _visibleIndices = _computeVisibleIndices();

    final List<List<_ProcessedPreviewCell>> list = [];
    for (final row in filtered) {
      final List<_ProcessedPreviewCell> cellList = [];
      for (final cIdx in _visibleIndices) {
        final cellVal = (cIdx < row.length ? row[cIdx]?.toString() : null) ?? '-';
        final colHeader = cIdx < widget.columns.length ? widget.columns[cIdx] : '';
        final isText = _isTextColumn(colHeader);
        final type = _detectCellType(cellVal, colHeader);

        cellList.add(_ProcessedPreviewCell(
          text: cellVal,
          type: type,
          isText: isText,
        ));
      }
      list.add(cellList);
    }

    setState(() {
      _processedRows = list;
      _currentPage = 1;
    });
  }

  PreviewCellType _detectCellType(String cellVal, String colHeader) {
    final valLower = cellVal.toLowerCase().trim();
    final hLower = colHeader.toLowerCase();

    if (valLower == 'present' || valLower == '1.0' || valLower == '1' || valLower == 'p') {
      return PreviewCellType.present;
    }
    if (valLower == 'absent' || valLower == '0.0' || valLower == '0' || valLower == 'a') {
      return PreviewCellType.absent;
    }
    if (valLower.contains('missed') || valLower == 'mp') {
      return PreviewCellType.missedPunch;
    }
    if (valLower.contains('half') || valLower == 'hd' || valLower == 'half_day') {
      return PreviewCellType.halfDay;
    }
    if (valLower.contains('leave') || valLower == 'l' || valLower == 'on leave') {
      return PreviewCellType.leave;
    }
    if (valLower.contains('late') || (hLower.contains('late') && (int.tryParse(cellVal) ?? 0) > 0)) {
      return PreviewCellType.late;
    }
    if (valLower.contains('holiday') || valLower == 'h') {
      return PreviewCellType.holiday;
    }
    if (valLower == 'wo' || valLower == 'week_off' || valLower == 'sun' || valLower == 'sat' || valLower.contains('weekend')) {
      return PreviewCellType.weekOff;
    }
    if (hLower.contains('overtime') || hLower.contains('ot')) {
      return PreviewCellType.overtime;
    }
    if (cellVal.contains('₹') || hLower.contains('salary') || hLower.contains('pay') || hLower.contains('amount')) {
      return PreviewCellType.currency;
    }
    return PreviewCellType.normal;
  }

  bool _isTextColumn(String header) {
    final h = header.toLowerCase();
    return h.contains('name') ||
        h.contains('department') ||
        h.contains('dept') ||
        h.contains('reason') ||
        h.contains('task') ||
        h.contains('remarks') ||
        h.contains('employee') ||
        h.contains('location') ||
        h.contains('designation') ||
        h.contains('role');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
          // ── 1. Excel Ribbon Toolbar Header ──────────────────────────────
          _buildExcelRibbonToolbar(isDark),

          // ── 2. Empty State or Spreadsheet View ──────────────────────────
          if (widget.columns.isEmpty || _processedRows.isEmpty || _visibleIndices.isEmpty)
            _buildEmptyState(isDark)
          else
            _buildSpreadsheetTable(isDark),

          // ── 3. Pagination Footer Bar ────────────────────────────────────
          if (_processedRows.length > 15)
            _buildPaginationBar(isDark),
        ],
      ),
    );
  }

  Widget _buildExcelRibbonToolbar(bool isDark) {
    final reportName = widget.reportTitle?.replaceAll('_', ' ').toUpperCase() ?? 'REPORT DATA';
    final totalRecords = _processedRows.where((r) {
      final first = r.isNotEmpty ? r[0].text.toUpperCase() : '';
      return first != 'TOTALS' && first != 'TOTAL';
    }).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Record Badge & Export Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Badge
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF107C41).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF107C41)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Excel Spreadsheet View",
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                reportName,
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.dateSubtitle != null && widget.dateSubtitle!.isNotEmpty) ...[
                                Text(
                                  " • ",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.dateSubtitle!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6366F1),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        "$totalRecords Records",
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Optional Quick Week Switcher for matrix_weekly
          if (widget.selectedReportType == 'matrix_weekly' &&
              widget.availableWeeks != null &&
              widget.availableWeeks!.isNotEmpty)
            _buildWeekSwitcherBar(isDark),

          const SizedBox(height: 8),

          // Bottom Row: Live Cross-Cell Search Input
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              controller: _localSearchController,
              onChanged: (v) {
                _effectiveSearch = v;
                _precomputeRows();
              },
              style: GoogleFonts.poppins(fontSize: 11),
              decoration: InputDecoration(
                hintText: "Search any value across all spreadsheet rows...",
                hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                suffixIcon: _effectiveSearch.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _localSearchController.clear();
                          _effectiveSearch = '';
                          _precomputeRows();
                        },
                        child: const Icon(Icons.close_rounded, size: 14),
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSwitcherBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.availableWeeks!.length,
        separatorBuilder: (_, index) => const SizedBox(width: 6),
        itemBuilder: (context, idx) {
          final w = widget.availableWeeks![idx];
          final isSelected = widget.selectedWeek?.value == w.value;
          return InkWell(
            onTap: () {
              if (widget.onWeekChanged != null) widget.onWeekChanged!(w);
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF161B22) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.view_week_rounded,
                    size: 13,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    w.label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF107C41).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.table_chart_outlined, size: 36, color: Color(0xFF107C41)),
            ),
            const SizedBox(height: 12),
            Text(
              "No spreadsheet records found",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Try selecting a different report type, month, or clearing search filters.",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. High Performance Excel-Replica Spreadsheet ───────────────────────
  Widget _buildSpreadsheetTable(bool isDark) {
    final totalItems = _processedRows.length;
    final startIndex = (_pageSize == -1) ? 0 : (_currentPage - 1) * _pageSize;
    final endIndex = (_pageSize == -1) ? totalItems : (startIndex + _pageSize).clamp(0, totalItems);
    final visibleRows = _processedRows.sublist(startIndex, endIndex);

    const double rowNumColWidth = 42.0;
    const double minColWidth = 135.0;
    final visibleCols = _visibleIndices.map((i) => widget.columns[i]).toList();
    final double dataColsWidth = visibleCols.length * minColWidth;

    const excelNavy = Color(0xFF1F4E78);
    const excelHeaderBorder = Color(0xFF2563EB);
    final gridLineColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: gridLineColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Frozen Left Column: Sticky Row Numbers (#) ──────────────────
          SizedBox(
            width: rowNumColWidth,
            child: Column(
              children: [
                // Header: #
                Container(
                  height: 42,
                  decoration: const BoxDecoration(
                    color: excelNavy,
                    border: Border(
                      bottom: BorderSide(color: excelHeaderBorder, width: 1.5),
                      right: BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "#",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Row Indices
                ...visibleRows.asMap().entries.map((entry) {
                  final rIdx = startIndex + entry.key;
                  final isTotalsRow = entry.value.isNotEmpty &&
                      (entry.value[0].text.toUpperCase() == 'TOTALS' || entry.value[0].text.toUpperCase() == 'TOTAL');
                  final isEven = rIdx % 2 == 0;

                  return Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isTotalsRow
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFDCE8F5))
                          : (isEven
                              ? (isDark ? const Color(0xFF1C2128) : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFD))),
                      border: Border(
                        bottom: BorderSide(
                          color: isTotalsRow ? const Color(0xFF2563EB) : gridLineColor,
                          width: isTotalsRow ? 2 : 1,
                        ),
                        right: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isTotalsRow ? "∑" : "${rIdx + 1}",
                      style: GoogleFonts.poppins(
                        fontSize: isTotalsRow ? 11 : 9.5,
                        fontWeight: isTotalsRow ? FontWeight.w800 : FontWeight.w600,
                        color: isTotalsRow
                            ? const Color(0xFF1E40AF)
                            : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Scrollable Right Columns: Table Data ────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: dataColsWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Excel Navy Headers Row
                    Container(
                      height: 42,
                      decoration: const BoxDecoration(
                        color: excelNavy,
                        border: Border(
                          bottom: BorderSide(color: excelHeaderBorder, width: 1.5),
                        ),
                      ),
                      child: Row(
                        children: visibleCols.map((col) {
                          final isText = _isTextColumn(col);
                          return Container(
                            width: minColWidth,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Color(0xFF2C4A68)),
                              ),
                            ),
                            alignment: isText ? Alignment.centerLeft : Alignment.center,
                            child: Text(
                              col.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Data Rows
                    ...visibleRows.asMap().entries.map((entry) {
                      final rIdx = startIndex + entry.key;
                      final row = entry.value;
                      final isTotalsRow = row.isNotEmpty &&
                          (row[0].text.toUpperCase() == 'TOTALS' || row[0].text.toUpperCase() == 'TOTAL');
                      final isEven = rIdx % 2 == 0;

                      return Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: isTotalsRow
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFDCE8F5))
                              : (isEven
                                  ? (isDark ? const Color(0xFF1C2128) : const Color(0xFFF8FAFD))
                                  : (isDark ? const Color(0xFF161B22) : Colors.white)),
                          border: Border(
                            bottom: BorderSide(
                              color: isTotalsRow ? const Color(0xFF2563EB) : gridLineColor,
                              width: isTotalsRow ? 2 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: row.asMap().entries.map((cEntry) {
                            final cIdx = cEntry.key;
                            final cell = cEntry.value;
                            final colHeader = cIdx < visibleCols.length ? visibleCols[cIdx] : '';

                            return _buildExcelCell(
                              cell: cell,
                              colHeader: colHeader,
                              isTotalsRow: isTotalsRow,
                              minColWidth: minColWidth,
                              gridLineColor: gridLineColor,
                              isDark: isDark,
                            );
                          }).toList(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelCell({
    required _ProcessedPreviewCell cell,
    required String colHeader,
    required bool isTotalsRow,
    required double minColWidth,
    required Color gridLineColor,
    required bool isDark,
  }) {
    Color? cellBg;
    Color textColor = isDark ? Colors.white70 : const Color(0xFF1E293B);
    FontWeight weight = cell.isText ? FontWeight.w600 : FontWeight.w500;
    FontStyle style = FontStyle.normal;

    if (isTotalsRow) {
      textColor = isDark ? Colors.white : const Color(0xFF1A3A5C);
      weight = FontWeight.w800;
    } else {
      switch (cell.type) {
        case PreviewCellType.present:
          cellBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFDCFCE7);
          textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.absent:
          cellBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEE2E2);
          textColor = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.missedPunch:
          cellBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
          textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.halfDay:
          cellBg = isDark ? const Color(0xFF713F12).withValues(alpha: 0.35) : const Color(0xFFFEF9C3);
          textColor = isDark ? const Color(0xFFFACC15) : const Color(0xFF854D0E);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.leave:
          cellBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFDBEAFE);
          textColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.late:
          cellBg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : const Color(0xFFFFF7ED);
          textColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.holiday:
          cellBg = isDark ? const Color(0xFF0369A1).withValues(alpha: 0.35) : const Color(0xFFE0F2FE);
          textColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.weekOff:
          cellBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
          textColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
          style = FontStyle.italic;
          break;
        case PreviewCellType.overtime:
          cellBg = isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.35) : const Color(0xFFF5F3FF);
          textColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.currency:
          textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
          weight = FontWeight.bold;
          break;
        case PreviewCellType.normal:
          break;
      }
    }

    return Container(
      width: minColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cellBg,
        border: Border(
          right: BorderSide(color: gridLineColor),
        ),
      ),
      alignment: cell.isText ? Alignment.centerLeft : Alignment.center,
      child: Text(
        cell.text,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: weight,
          fontStyle: style,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── 3. Pagination Bar ───────────────────────────────────────────────────
  Widget _buildPaginationBar(bool isDark) {
    final totalItems = _processedRows.length;
    final totalPages = (_pageSize == -1) ? 1 : ((totalItems / _pageSize).ceil());
    final startIndex = (_pageSize == -1) ? 0 : (_currentPage - 1) * _pageSize;
    final endIndex = (_pageSize == -1) ? totalItems : (startIndex + _pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${startIndex + 1}–$endIndex of $totalItems rows",
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              // Custom Page size selector
              PopupMenuButton<int>(
                initialValue: _pageSize,
                tooltip: "Rows per page",
                offset: const Offset(0, -145),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                onSelected: (val) {
                  setState(() {
                    _pageSize = val;
                    _currentPage = 1;
                  });
                },
                itemBuilder: (ctx) => [15, 25, 50, -1].map((val) {
                  final label = val == -1 ? "All rows" : "$val / page";
                  final isSel = _pageSize == val;
                  return PopupMenuItem<int>(
                    value: val,
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel
                                ? const Color(0xFF6366F1)
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        if (isSel)
                          const Icon(Icons.check_rounded, size: 14, color: Color(0xFF6366F1)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageSize == -1 ? "All" : "$_pageSize / pg",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Prev Button
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  padding: const EdgeInsets.all(3),
                  minimumSize: const Size(26, 26),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "$_currentPage / $totalPages",
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),

              // Next Button
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                  padding: const EdgeInsets.all(3),
                  minimumSize: const Size(26, 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
