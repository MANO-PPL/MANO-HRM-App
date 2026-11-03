import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_record.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/widgets/interactive_image_viewer.dart';

class AttendanceHistoryTab extends StatefulWidget {
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const AttendanceHistoryTab({
    super.key, 
    this.shrinkWrap = false, 
    this.physics,
    this.padding,
  });

  @override
  State<AttendanceHistoryTab> createState() => _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends State<AttendanceHistoryTab> {
  final DateTime _selectedMonth = DateTime.now();
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchMonthRecords();
    });
  }

  Future<void> _fetchMonthRecords() async {
    setState(() => _isLoading = true);
    try {
      final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      
      final provider = Provider.of<AttendanceProvider>(context, listen: false);
      final data = await provider.fetchRange(firstDay, lastDay);
      
      if (mounted) {
        setState(() {
          _records = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Injects absent-day placeholders for working days with no recorded attendance.
  List<_TabDayEntry> _buildDayEntries(List<AttendanceRecord> records) {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final Map<String, List<AttendanceRecord>> recordsByDate = {};
    for (final r in records) {
      if (r.timeIn == null) continue;
      try {
        final dt = DateTime.parse(r.timeIn!);
        final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        recordsByDate.putIfAbsent(key, () => []).add(r);
      } catch (_) {}
    }

    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final entries = <_TabDayEntry>[];

    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(_selectedMonth.year, _selectedMonth.month, d);
      final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

      if (dateStr.compareTo(todayStr) >= 0) continue;

      if (recordsByDate.containsKey(dateStr)) {
        for (final r in recordsByDate[dateStr]!) {
          entries.add(_TabDayEntry(dateStr: dateStr, date: dt, record: r, isAbsent: false));
        }
      } else {
        final dow = dt.weekday;
        if (dow >= 1 && dow <= 5) {
          entries.add(_TabDayEntry(dateStr: dateStr, date: dt, record: null, isAbsent: true));
        }
      }
    }

    entries.sort((a, b) => b.dateStr.compareTo(a.dateStr));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final dayEntries = _buildDayEntries(_records);

    final Map<int, List<_TabDayEntry>> groupedByWeek = {};
    for (final entry in dayEntries) {
      final weekOfMonth = ((entry.date.day - 1) ~/ 7) + 1;
      groupedByWeek.putIfAbsent(weekOfMonth, () => []).add(entry);
    }
    final sortedWeeks = groupedByWeek.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        if (dayEntries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.history_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    "No records found for this month",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedWeeks.map((week) {
            final weekEntries = groupedByWeek[week]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWeekSection(context, 'Week $week', weekEntries),
            );
          }),
      ],
    );
  }

  Widget _buildWeekSection(BuildContext context, String title, List<_TabDayEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ...entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8), 
          child: entry.isAbsent
              ? _buildAbsentCard(context, entry.date)
              : _buildHistoryCard(entry.record!),
        )),
      ],
    );
  }

  Widget _buildHistoryCard(AttendanceRecord record) {
    final timeIn = DateTime.parse(record.timeIn!);
    final day = timeIn.day;
    final dateStr = DateFormat('d MMMM yyyy').format(timeIn);
    
    final status = record.status.toUpperCase();
    final isLate = status == 'LATE';
    final isAbsent = status == 'ABSENT';
    final isMissedPunch = status == 'MISSED_PUNCH';

    // Web-aligned: absent = muted grey (not red)
    Color? statusBg;
    Color? statusText;
    if (isLate) {
      statusBg = Colors.orange;
      statusText = Colors.orange[800];
    } else if (isAbsent) {
      statusBg = Colors.grey[300];
      statusText = Colors.grey[700];
    } else if (isMissedPunch) {
      statusBg = Colors.red[100];
      statusText = Colors.red[700];
    } else {
      statusBg = Colors.green[100];
      statusText = Colors.green[800];
    }

    String displayIn = DateFormat('hh:mm a').format(timeIn);
    String displayOut = '-';
    String hrs = '-';

    if (record.timeOut != null) {
      final timeOut = DateTime.parse(record.timeOut!);
      displayOut = DateFormat('hh:mm a').format(timeOut);
      
      final diff = timeOut.difference(timeIn);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      hrs = '${hours}h ${minutes}m';
    }

    final location = record.timeInAddress ?? 'Unknown Location';

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Box
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$day', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF5B60F6))),
                    ),
                    const SizedBox(width: 12),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr, 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusBg?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(status, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: statusText)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location, 
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTimeColumn('IN', displayIn, imageUrl: record.timeInImage),
                    _buildTimeColumn('OUT', displayOut, imageUrl: record.timeOutImage),
                    _buildTimeColumn('HRS', hrs),
                  ],
                ),
                _buildCheckpointsRow(record),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Date Box
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$day', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF5B60F6))),
                    ),
                    const SizedBox(width: 12),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dateStr, 
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusBg?.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(status, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: statusText)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location, 
                                  style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Times
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTimeColumn('IN', displayIn, imageUrl: record.timeInImage),
                            const SizedBox(width: 6),
                            _buildTimeColumn('OUT', displayOut, imageUrl: record.timeOutImage),
                            const SizedBox(width: 6),
                            _buildTimeColumn('HRS', hrs),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
                _buildCheckpointsRow(record),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCheckpointsRow(AttendanceRecord record) {
    if (record.checkpoints.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              Text(
                'CHECKPOINTS (${record.checkpoints.length})',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: record.checkpoints.asMap().entries.map((e) {
              final idx = e.key;
              final cp = e.value;
              final cpUrl = cp.imageUrl;
              final hasImg = cpUrl != null && cpUrl.trim().isNotEmpty;
              return InkWell(
                onTap: hasImg
                    ? () => InteractiveImageViewerDialog.show(context, cpUrl.trim(), title: "Checkpoint #${idx + 1} Selfie")
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasImg) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: cpUrl.trim(),
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFD97706)),
                            ),
                            errorWidget: (context, url, error) => Image.network(
                              cpUrl.trim(),
                              width: 22,
                              height: 22,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.camera_alt, size: 14, color: Color(0xFFD97706)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '#${idx + 1}${hasImg ? ' • View' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String value, {String? imageUrl}) {
    final isUndefined = value == '-' || value.isEmpty;

    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (imageUrl != null && imageUrl.trim().isNotEmpty && !isUndefined)
          InkWell(
            onTap: () => InteractiveImageViewerDialog.show(context, imageUrl.trim(), title: "$label Selfie"),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.remove_red_eye_rounded, size: 12, color: Theme.of(context).primaryColor),
                ],
              ),
            ),
          )
        else
          Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _TabDayEntry {
  final String dateStr;
  final DateTime date;
  final AttendanceRecord? record;
  final bool isAbsent;

  _TabDayEntry({required this.dateStr, required this.date, this.record, required this.isAbsent});
}

// ─── Absent Card ──────────────────────────────────────────────────────────────

extension _AbsentTabCardExt on _AttendanceHistoryTabState {
  Widget _buildAbsentCard(BuildContext context, DateTime date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final day = date.day;
    final dateLabel = DateFormat('d MMMM yyyy').format(date);

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isDark ? Colors.grey[800] : Colors.grey[200])!,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$day',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ABSENT',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// [upd:2026-04-16T11:30:00+05:30]
