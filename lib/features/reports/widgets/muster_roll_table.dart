import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/shared/widgets/pfp_viewer_dialog.dart';

class MusterRollTable extends StatefulWidget {
  final MusterRollData musterRoll;
  final String searchQuery;
  final VoidCallback? onExportExcel;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportPdf;
  final bool isExporting;

  const MusterRollTable({
    super.key,
    required this.musterRoll,
    this.searchQuery = '',
    this.onExportExcel,
    this.onExportCsv,
    this.onExportPdf,
    this.isExporting = false,
  });

  @override
  State<MusterRollTable> createState() => _MusterRollTableState();
}

class _MusterRollTableState extends State<MusterRollTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  String _searchQuery = '';

  static const double _headerHeight = 44.0;
  static const double _statusRowHeight = 34.0;
  static const double _otherRowHeight = 26.0;

  static const double _empColWidth = 125.0;
  static const double _typeColWidth = 62.0;
  static const double _dateColWidth = 44.0;
  static const double _daysColWidth = 44.0;
  static const double _presColWidth = 48.0;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery;
  }

  @override
  void didUpdateWidget(covariant MusterRollTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() => _searchQuery = widget.searchQuery);
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final q = _searchQuery.toLowerCase().trim();

    final filteredEmployees = widget.musterRoll.employees.where((emp) {
      if (q.isEmpty) return true;
      return emp.name.toLowerCase().contains(q) ||
          emp.employeeCode.toLowerCase().contains(q) ||
          emp.position.toLowerCase().contains(q);
    }).toList();

    final headers = widget.musterRoll.dateHeaders;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title Bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_view_rounded, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${widget.musterRoll.companyName.isNotEmpty ? '${widget.musterRoll.companyName} • ' : ''}${widget.musterRoll.monthTitle} Attendance Muster Roll",
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${filteredEmployees.length} Staff",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Daily Formula Keys & Legend Bar (Identical to Web) ──────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    "Formula Keys: ",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  _buildFormulaChip("P", "Present (=1)", const Color(0xFF10B981), isDark),
                  _buildFormulaChip("H", "Holiday (=1)", const Color(0xFF6366F1), isDark),
                  _buildFormulaChip("WO", "Week Off (=1)", const Color(0xFF64748B), isDark),
                  _buildFormulaChip("PL", "Paid Leave (=1)", const Color(0xFF0284C7), isDark),
                  _buildFormulaChip("HD", "Half Day (=0.5)", const Color(0xFFF59E0B), isDark),
                  _buildFormulaChip("A", "Absent (=0)", const Color(0xFFEF4444), isDark),
                  _buildFormulaChip("UL", "Unpaid Leave (=0)", const Color(0xFFEC4899), isDark),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B2E0A) : const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isDark ? const Color(0xFF71550E) : const Color(0xFFFACC15),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      "Holiday / Sunday (1.0)",
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Synchronized Table Area: Pinned Employee + Scrollable Dates ──
          Expanded(
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalController,
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Frozen Left Columns: Employee Info & Punch Type
                    _buildFrozenLeftTable(isDark, borderColor, filteredEmployees),

                    // 2. Horizontally Scrollable Right Columns: Dates + Totals
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontalController,
                        notificationPredicate: (notif) => notif.depth == 1,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: _buildScrollableRightTable(
                            isDark,
                            borderColor,
                            filteredEmployees,
                            headers,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaChip(String code, String desc, Color col, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: col.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(2.5),
            ),
            child: Text(
              code,
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ── Frozen Left Table: Employee Details + Row Type ──────────────────────
  Widget _buildFrozenLeftTable(
    bool isDark,
    Color borderColor,
    List<MusterRollEmployee> employees,
  ) {
    final headerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);

    final List<TableRow> rows = [
      // Header Row
      TableRow(
        decoration: BoxDecoration(color: headerBg),
        children: [
          Container(
            height: _headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            child: Text(
              "EMPLOYEE",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            height: _headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            child: Text(
              "TYPE",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    ];

    for (int i = 0; i < employees.length; i++) {
      final emp = employees[i];
      final isEven = i % 2 == 0;
      final rowBg = isEven
          ? (isDark ? const Color(0xFF0D1117) : Colors.white)
          : (isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC));

      final subRows = [
        {'label': 'Status', 'isStatus': true},
        if (emp.workHourRow.isNotEmpty) {'label': 'Work Hour', 'isStatus': false},
        if (emp.inRow.isNotEmpty) {'label': 'In', 'isStatus': false},
        if (emp.outRow.isNotEmpty) {'label': 'Out', 'isStatus': false},
      ];

      for (int sIdx = 0; sIdx < subRows.length; sIdx++) {
        final sub = subRows[sIdx];
        final isFirst = sIdx == 0;
        final double rHeight = isFirst ? _statusRowHeight : _otherRowHeight;

        rows.add(
          TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: [
              // Employee Name & Code column
              Container(
                height: rHeight,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                alignment: Alignment.centerLeft,
                child: isFirst
                    ? GestureDetector(
                        onTap: () {
                          PfpViewerDialog.show(
                            context,
                            imageUrl: null,
                            name: emp.name,
                            subtitle: "${emp.employeeCode}${emp.position.isNotEmpty ? ' • ${emp.position}' : ''}",
                            heroTag: 'muster-emp-pfp-${emp.userId}',
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              "${emp.srNo}",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emp.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "${emp.employeeCode}${emp.position.isNotEmpty ? ' • ${emp.position}' : ''}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 8.5,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Punch Type Label Column (Status, Work Hour, In, Out)
              Container(
                height: rHeight,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                child: Text(
                  sub['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                    color: isFirst
                        ? (isDark ? Colors.white70 : const Color(0xFF334155))
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(60),
        columnWidths: const {
          0: FixedColumnWidth(_empColWidth),
          1: FixedColumnWidth(_typeColWidth),
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: borderColor, width: 0.5),
          verticalInside: BorderSide(color: borderColor, width: 0.5),
        ),
        children: rows,
      ),
    );
  }

  // ── Scrollable Right Table: Dates & Summary Columns ─────────────────────
  Widget _buildScrollableRightTable(
    bool isDark,
    Color borderColor,
    List<MusterRollEmployee> employees,
    List<MusterRollDateHeader> headers,
  ) {
    final headerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);

    final Map<int, TableColumnWidth> colWidths = {};
    for (int i = 0; i < headers.length; i++) {
      colWidths[i] = const FixedColumnWidth(_dateColWidth);
    }
    colWidths[headers.length] = const FixedColumnWidth(_daysColWidth);
    colWidths[headers.length + 1] = const FixedColumnWidth(_presColWidth);

    final List<TableRow> rows = [
      // Header Row
      TableRow(
        decoration: BoxDecoration(color: headerBg),
        children: [
          ...headers.map((h) => _buildDateHeaderCell(h, isDark)),
          _buildSummaryHeaderCell("DAYS", isDark, _daysColWidth),
          _buildSummaryHeaderCell("PRES", isDark, _presColWidth),
        ],
      ),
    ];

    for (int i = 0; i < employees.length; i++) {
      final emp = employees[i];
      final isEven = i % 2 == 0;
      final rowBg = isEven
          ? (isDark ? const Color(0xFF0D1117) : Colors.white)
          : (isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC));

      final subRows = [
        {'label': 'Status', 'data': emp.statusRow, 'isStatus': true},
        if (emp.workHourRow.isNotEmpty) {'label': 'Work Hour', 'data': emp.workHourRow, 'isStatus': false},
        if (emp.inRow.isNotEmpty) {'label': 'In', 'data': emp.inRow, 'isStatus': false},
        if (emp.outRow.isNotEmpty) {'label': 'Out', 'data': emp.outRow, 'isStatus': false},
      ];

      for (int sIdx = 0; sIdx < subRows.length; sIdx++) {
        final sub = subRows[sIdx];
        final isFirst = sIdx == 0;
        final isStatus = sub['isStatus'] as bool;
        final dataRow = sub['data'] as List<String>;
        final double rHeight = isFirst ? _statusRowHeight : _otherRowHeight;

        rows.add(
          TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: [
              // Date Cells for this sub-row
              for (int c = 0; c < headers.length; c++)
                _buildDataCell(
                  c < dataRow.length ? dataRow[c] : "-",
                  isStatus,
                  headers[c],
                  isDark,
                  rHeight,
                ),

              // Days Column
              Container(
                height: rHeight,
                alignment: Alignment.center,
                child: isFirst
                    ? Text(
                        "${emp.daysInMonth}",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Present Days Column
              Container(
                height: rHeight,
                alignment: Alignment.center,
                child: isFirst
                    ? Text(
                        emp.presentDays,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }
    }

    return Table(
      defaultColumnWidth: const FixedColumnWidth(_dateColWidth),
      columnWidths: colWidths,
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 0.5),
        verticalInside: BorderSide(color: borderColor, width: 0.5),
      ),
      children: rows,
    );
  }

  Widget _buildSummaryHeaderCell(String text, bool isDark, double width) {
    return Container(
      height: _headerHeight,
      width: width,
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDateHeaderCell(MusterRollDateHeader h, bool isDark) {
    final isSunOrHol = h.isHighlight || h.isSunday || h.isHoliday;

    // Matching Web Theme (Yellow highlight for Sunday & Holiday)
    final bgCol = isSunOrHol
        ? (isDark ? const Color(0xFF3D320A) : const Color(0xFFFEF08A))
        : Colors.transparent;
    final textCol = isSunOrHol
        ? (isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E))
        : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B));
    final dayNumCol = isSunOrHol
        ? (isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E))
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    return Container(
      height: _headerHeight,
      color: bgCol,
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            h.dayOfWeek.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: textCol,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            h.dayNum,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dayNumCol,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(
    String val,
    bool isStatus,
    MusterRollDateHeader header,
    bool isDark,
    double height,
  ) {
    final isSunOrHol = header.isHighlight || header.isSunday || header.isHoliday;

    // Subtle yellow column tint for Sunday and Holiday columns (identical to web)
    final colBg = isSunOrHol
        ? (isDark
            ? const Color(0xFF26200A).withValues(alpha: 0.7)
            : const Color(0xFFFEF9C3).withValues(alpha: 0.5))
        : Colors.transparent;

    if (isStatus) {
      final s = val.trim().toUpperCase();
      Color badgeBg = Colors.transparent;
      Color textCol = isDark ? Colors.white70 : const Color(0xFF334155);
      FontWeight fw = FontWeight.w500;

      if (s == 'P' || s.contains('PRESENT')) {
        badgeBg = isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.25)
            : const Color(0xFFDCFCE7);
        textCol = isDark ? const Color(0xFF34D399) : const Color(0xFF15803D);
        fw = FontWeight.w700;
      } else if (s == 'A' || s == 'ABSENT') {
        badgeBg = isDark
            ? const Color(0xFFEF4444).withValues(alpha: 0.25)
            : const Color(0xFFFEE2E2);
        textCol = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        fw = FontWeight.w700;
      } else if (s == 'L' || s == 'LEAVE' || s == 'PL') {
        badgeBg = isDark
            ? const Color(0xFF0284C7).withValues(alpha: 0.25)
            : const Color(0xFFE0F2FE);
        textCol = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        fw = FontWeight.w700;
      } else if (s == 'HD' || s == 'HALF_DAY') {
        badgeBg = isDark
            ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
            : const Color(0xFFFEF3C7);
        textCol = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        fw = FontWeight.w700;
      } else if (s == 'WO') {
        badgeBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
        textCol = const Color(0xFF64748B);
      } else if (s == 'H') {
        badgeBg = isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.25)
            : const Color(0xFFE0E7FF);
        textCol = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
      }

      return Container(
        height: height,
        color: colBg,
        alignment: Alignment.center,
        child: Container(
          height: 23,
          width: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            s.isNotEmpty ? s : "-",
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: fw,
              color: textCol,
            ),
          ),
        ),
      );
    }

    // Normal text cell (Work hours, In punch, Out punch)
    return Container(
      height: height,
      color: colBg,
      alignment: Alignment.center,
      child: Text(
        val.isNotEmpty ? val : "-",
        style: GoogleFonts.poppins(
          fontSize: 8.5,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white60 : const Color(0xFF475569),
        ),
      ),
    );
  }
}
