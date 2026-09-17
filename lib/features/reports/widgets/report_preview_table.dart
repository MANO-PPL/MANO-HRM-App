import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PreviewCellType {
  normal,
  present,
  absent,
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
  final String searchQuery;
  final String? reportTitle;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportPdf;
  final bool isExporting;

  const ReportPreviewTable({
    super.key,
    required this.columns,
    required this.rows,
    this.searchQuery = '',
    this.reportTitle,
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

  // Pagination State
  int _currentPage = 1;
  int _pageSize = 25;

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
    if (widget.columns != oldWidget.columns ||
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

  void _precomputeRows() {
    final q = _effectiveSearch.toLowerCase().trim();

    final filtered = widget.rows.where((row) {
      if (q.isEmpty) return true;
      return row.any((cell) => cell?.toString().toLowerCase().contains(q) == true);
    }).toList();

    final List<List<_ProcessedPreviewCell>> list = [];
    for (final row in filtered) {
      final List<_ProcessedPreviewCell> cellList = [];
      for (int cIdx = 0; cIdx < row.length; cIdx++) {
        final cellVal = row[cIdx]?.toString() ?? '-';
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
          if (widget.columns.isEmpty || _processedRows.isEmpty)
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
              Row(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Excel Spreadsheet View",
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        reportName,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
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
            ],
          ),

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
    final double dataColsWidth = widget.columns.length * minColWidth;

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
                        children: widget.columns.map((col) {
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
                            final colHeader = cIdx < widget.columns.length ? widget.columns[cIdx] : '';

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
          cellBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7);
          textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
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
              // Page size selector
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text("15 / pg")),
                      DropdownMenuItem(value: 25, child: Text("25 / pg")),
                      DropdownMenuItem(value: 50, child: Text("50 / pg")),
                      DropdownMenuItem(value: -1, child: Text("All")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                      }
                    },
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
