import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';
import 'package:flutter_application/features/reports/widgets/attendance_detail_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/widgets/pfp_viewer_dialog.dart';

class _DateHeaderInfo {
  final String dateStr;
  final String monthShort;
  final String dayNum;
  final String weekdayShort;
  final bool isSunday;

  const _DateHeaderInfo({
    required this.dateStr,
    required this.monthShort,
    required this.dayNum,
    required this.weekdayShort,
    required this.isSunday,
  });
}

class AttendanceMatrixTable extends StatefulWidget {
  final List<AttendanceMatrixEmployee> matrix;
  final List<String> dates;
  final String searchQuery;

  const AttendanceMatrixTable({
    super.key,
    required this.matrix,
    required this.dates,
    this.searchQuery = '',
  });

  @override
  State<AttendanceMatrixTable> createState() => _AttendanceMatrixTableState();
}

class _AttendanceMatrixTableState extends State<AttendanceMatrixTable> {
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();
  List<_DateHeaderInfo> _cachedHeaders = [];

  // Configured summary columns (matching Web SUMMARY_FILTER_OPTIONS)
  // Available: 'P', 'A', 'LT', 'MP', 'L', 'HD', 'WO', 'H', 'OT'
  final Set<String> _pinnedSummaryKeys = {'P', 'A'};
  bool _isAllTotalsSticky = false;

  // Pagination State
  int _currentPage = 1;
  static const int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _recomputeHeaders();
  }

  @override
  void didUpdateWidget(covariant AttendanceMatrixTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dates != oldWidget.dates) {
      _recomputeHeaders();
    }
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _recomputeHeaders() {
    final List<_DateHeaderInfo> headers = [];
    for (final dStr in widget.dates) {
      DateTime? dt;
      try {
        dt = DateTime.parse(dStr);
      } catch (_) {}

      final isSun = dt?.weekday == DateTime.sunday;
      headers.add(_DateHeaderInfo(
        dateStr: dStr,
        monthShort: dt != null ? DateFormat('MMM').format(dt).toUpperCase() : 'DAY',
        dayNum: dt != null ? '${dt.day}' : '0',
        weekdayShort: dt != null ? DateFormat('E').format(dt).toUpperCase() : '',
        isSunday: isSun,
      ));
    }
    _cachedHeaders = headers;
  }

  void _showSummaryColumnsDialog(BuildContext context, bool isDark) {
    const options = [
      {'key': 'P', 'label': 'P', 'title': 'Present (P)', 'desc': 'Total days employee attended'},
      {'key': 'A', 'label': 'A', 'title': 'Absent (A)', 'desc': 'Total days marked absent'},
      {'key': 'LT', 'label': 'LT', 'title': 'Late (LT)', 'desc': 'Days with late arrival'},
      {'key': 'MP', 'label': 'MP', 'title': 'Missed Punch (MP)', 'desc': 'Single punch without checkout'},
      {'key': 'L', 'label': 'L', 'title': 'Leave (L)', 'desc': 'Approved paid and unpaid leaves'},
      {'key': 'HD', 'label': 'HD', 'title': 'Half Day (HD)', 'desc': 'Half day attendance records'},
      {'key': 'WO', 'label': 'WO', 'title': 'Weekly Off (WO)', 'desc': 'Scheduled weekly off days'},
      {'key': 'H', 'label': 'H', 'title': 'Holiday (H)', 'desc': 'Company and public holidays'},
      {'key': 'OT', 'label': 'OT', 'title': 'Overtime (OT)', 'desc': 'Total overtime hours worked'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Summary Columns",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                Text(
                  "Choose which summary metrics to display in the attendance matrix table",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((opt) {
                      final k = opt['key']!;
                      final isSelected = _pinnedSummaryKeys.contains(k);
                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            opt['title']!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            opt['desc']!,
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                          ),
                          activeColor: const Color(0xFF6366F1),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                _pinnedSummaryKeys.add(k);
                              } else {
                                if (_pinnedSummaryKeys.length > 1) {
                                  _pinnedSummaryKeys.remove(k);
                                }
                              }
                            });
                            setState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      "Apply Selection (${_pinnedSummaryKeys.length} Columns)",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _togglePinTotals() {
    setState(() {
      _isAllTotalsSticky = !_isAllTotalsSticky;
    });
    if (_isAllTotalsSticky && _horizontalScroll.hasClients) {
      _horizontalScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = widget.searchQuery.toLowerCase().trim();

    final filtered = widget.matrix.where((emp) {
      if (q.isEmpty) return true;
      return emp.name.toLowerCase().contains(q) ||
          emp.employeeId.toLowerCase().contains(q) ||
          emp.department.toLowerCase().contains(q);
    }).toList();

    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, filtered.length);
    final pagedEmployees = startIndex < filtered.length
        ? filtered.sublist(startIndex, endIndex)
        : <AttendanceMatrixEmployee>[];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Toolbar Header: Record count, Summary columns filter, Sticky toggle ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 480;

              final columnsButton = InkWell(
                onTap: () => _showSummaryColumnsDialog(context, isDark),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_column_outlined, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        "Columns (${_pinnedSummaryKeys.length})",
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final pinButton = InkWell(
                onTap: _togglePinTotals,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isAllTotalsSticky
                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF161B22) : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isAllTotalsSticky
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: _isAllTotalsSticky ? const Color(0xFF6366F1) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isAllTotalsSticky ? "Totals Pinned" : "Pin Totals",
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _isAllTotalsSticky
                              ? const Color(0xFF6366F1)
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Attendance Matrix",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${filtered.length} Staff",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: columnsButton),
                              const SizedBox(width: 8),
                              Expanded(child: pinButton),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Text(
                            "Attendance Matrix",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${filtered.length} Staff",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                          const Spacer(),
                          columnsButton,
                          const SizedBox(width: 8),
                          pinButton,
                        ],
                      ),
              );
            },
          ),

          // ── Scrollable Matrix Table ─────────────────────────────────────────
          Expanded(
            child: Scrollbar(
              controller: _verticalScroll,
              thumbVisibility: true,
              child: Scrollbar(
                controller: _horizontalScroll,
                notificationPredicate: (notif) => notif.depth == 1,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScroll,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: _buildGridTable(isDark, pagedEmployees),
                  ),
                ),
              ),
            ),
          ),

          // ── Pagination Footer ───────────────────────────────────────────────
          if (filtered.length > _pageSize)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Showing ${startIndex + 1} - $endIndex of ${filtered.length}",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        onPressed: currentPage > 1
                            ? () => setState(() => _currentPage = currentPage - 1)
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      Text(
                        "$currentPage / $totalPages",
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        onPressed: currentPage < totalPages
                            ? () => setState(() => _currentPage = currentPage + 1)
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGridTable(bool isDark, List<AttendanceMatrixEmployee> employees) {
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);

    final summaryKeys = _isAllTotalsSticky
        ? const ['P', 'A', 'LT', 'MP', 'L', 'HD', 'WO', 'H', 'OT']
        : _pinnedSummaryKeys.toList();

    final Map<int, TableColumnWidth> colWidths = {
      0: const FixedColumnWidth(180), // Employee Name & ID
    };

    if (_isAllTotalsSticky) {
      for (int s = 0; s < summaryKeys.length; s++) {
        colWidths[1 + s] = const FixedColumnWidth(46);
      }
      for (int i = 0; i < _cachedHeaders.length; i++) {
        colWidths[1 + summaryKeys.length + i] = const FixedColumnWidth(42);
      }
    } else {
      for (int i = 0; i < _cachedHeaders.length; i++) {
        colWidths[1 + i] = const FixedColumnWidth(42);
      }
      for (int s = 0; s < summaryKeys.length; s++) {
        colWidths[1 + _cachedHeaders.length + s] = const FixedColumnWidth(46);
      }
    }

    final employeeHeader = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    );

    final dateHeaders = _cachedHeaders.map((hdr) => _buildDateHeader(hdr, isDark)).toList();
    final summaryHeaders = summaryKeys.map((k) => _buildSummaryHeader(k, isDark)).toList();

    return Table(
      defaultColumnWidth: const FixedColumnWidth(44),
      columnWidths: colWidths,
      border: TableBorder.all(color: borderColor, width: 1),
      children: [
        // Table Header
        TableRow(
          decoration: BoxDecoration(color: headerBg),
          children: [
            employeeHeader,
            if (_isAllTotalsSticky) ...summaryHeaders,
            ...dateHeaders,
            if (!_isAllTotalsSticky) ...summaryHeaders,
          ],
        ),

        // Table Rows
        for (int i = 0; i < employees.length; i++)
          _buildEmployeeRow(employees[i], i, isDark, summaryKeys, _isAllTotalsSticky),
      ],
    );
  }

  Widget _buildDateHeader(_DateHeaderInfo hdr, bool isDark) {
    final isSun = hdr.isSunday;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: isSun
          ? (isDark ? const Color(0xFF3B1219) : const Color(0xFFFFECEF))
          : Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hdr.weekdayShort,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: isSun
                  ? const Color(0xFFE11D48)
                  : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
            ),
          ),
          Text(
            hdr.dayNum,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isSun
                  ? const Color(0xFFE11D48)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(String key, bool isDark) {
    Color col = const Color(0xFF6366F1);
    if (key == 'P') col = const Color(0xFF10B981);
    if (key == 'A') col = const Color(0xFFEF4444);
    if (key == 'LT') col = const Color(0xFFF97316);
    if (key == 'MP') col = const Color(0xFFF59E0B);
    if (key == 'L') col = const Color(0xFF0284C7);
    if (key == 'HD') col = const Color(0xFF6366F1);
    if (key == 'WO') col = const Color(0xFF64748B);
    if (key == 'H') col = const Color(0xFF0284C7);
    if (key == 'OT') col = const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      color: col.withValues(alpha: isDark ? 0.15 : 0.08),
      alignment: Alignment.center,
      child: Text(
        key,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: col,
        ),
      ),
    );
  }

  TableRow _buildEmployeeRow(
    AttendanceMatrixEmployee emp,
    int idx,
    bool isDark,
    List<String> summaryKeys,
    bool pinTotalsUpfront,
  ) {
    final isEven = idx % 2 == 0;
    final rowBg = isEven
        ? (isDark ? const Color(0xFF0D1117) : Colors.white)
        : (isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC));

    final dateCells = _cachedHeaders.map((hdr) {
      final rec = emp.dailyRecords[hdr.dateStr] ??
          AttendanceMatrixDayRecord(date: hdr.dateStr, status: hdr.isSunday ? 'WO' : '-');
      return _buildCell(context, emp, rec, hdr.isSunday, isDark);
    }).toList();

    final summaryCells = summaryKeys.map((k) {
      int count = 0;
      double ot = 0.0;
      if (k == 'P') count = emp.presentCount;
      if (k == 'A') count = emp.absentCount;
      if (k == 'LT') count = emp.lateCount;
      if (k == 'MP') count = emp.missedPunchCount;
      if (k == 'L') count = emp.leaveCount;
      if (k == 'HD') count = emp.halfDayCount;
      if (k == 'WO') count = emp.weeklyOffCount;
      if (k == 'H') count = emp.holidayCount;
      if (k == 'OT') ot = emp.overtimeHours;

      final valStr = k == 'OT' ? ot.toStringAsFixed(1) : '$count';

      Color col = const Color(0xFF6366F1);
      if (k == 'P') col = const Color(0xFF10B981);
      if (k == 'A') col = const Color(0xFFEF4444);
      if (k == 'LT') col = const Color(0xFFF97316);
      if (k == 'MP') col = const Color(0xFFF59E0B);
      if (k == 'L') col = const Color(0xFF0284C7);
      if (k == 'HD') col = const Color(0xFF6366F1);
      if (k == 'WO') col = const Color(0xFF64748B);
      if (k == 'H') col = const Color(0xFF0284C7);
      if (k == 'OT') col = const Color(0xFF8B5CF6);

      return Container(
        height: 38,
        color: col.withValues(alpha: isDark ? 0.08 : 0.04),
        alignment: Alignment.center,
        child: Text(
          valStr,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: col,
          ),
        ),
      );
    }).toList();

    return TableRow(
      decoration: BoxDecoration(color: rowBg),
      children: [
        // Employee Info Card (Leftmost sticky)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  PfpViewerDialog.show(
                    context,
                    imageUrl: emp.avatarUrl,
                    name: emp.name,
                    subtitle: '${emp.employeeId} • ${emp.department}',
                    heroTag: 'matrix-emp-pfp-${emp.userId}',
                  );
                },
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  child: emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: emp.avatarUrl!,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, err) => Text(
                              emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emp.name,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${emp.employeeId} • ${emp.department}",
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
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
        ),

        // If pinned upfront, render summary totals right next to Employee column
        if (pinTotalsUpfront) ...summaryCells,

        // Date Cells
        ...dateCells,

        // If not pinned upfront, render summary totals at the far right
        if (!pinTotalsUpfront) ...summaryCells,
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    AttendanceMatrixEmployee emp,
    AttendanceMatrixDayRecord rec,
    bool isSunday,
    bool isDark,
  ) {
    final status = rec.shortStatus;
    final color = rec.statusColor;

    Color bg = Colors.transparent;
    if (status == 'P') bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'A') bg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'L') bg = const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'HD') bg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'MP') bg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'WO') bg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
    if (status == 'H') bg = const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.15);
    if (status == 'OT') bg = const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.15);

    return InkWell(
      onTap: () => AttendanceDetailSheet.show(context, employee: emp, record: rec),
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          status.isNotEmpty ? status : "-",
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: (status == 'P' || status == 'A' || status == 'L')
                ? FontWeight.w700
                : FontWeight.w500,
            color: color,
          ),
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }
}
