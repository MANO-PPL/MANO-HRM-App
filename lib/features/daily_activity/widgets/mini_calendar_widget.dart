import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Callback with [startDate] and optional [endDate] (null = single day).
typedef OnRangeSelect = void Function(String startDate, String? endDate);

class MiniCalendarWidget extends StatefulWidget {
  /// The primary selected / anchor date (YYYY-MM-DD).
  final String selectedDate;

  /// Optional range end date (YYYY-MM-DD). When not null, days between
  /// [selectedDate] and [rangeEndDate] are highlighted.
  final String? rangeEndDate;

  final OnRangeSelect onRangeSelect;

  const MiniCalendarWidget({
    super.key,
    required this.selectedDate,
    this.rangeEndDate,
    required this.onRangeSelect,
  });

  @override
  State<MiniCalendarWidget> createState() => _MiniCalendarWidgetState();
}

class _MiniCalendarWidgetState extends State<MiniCalendarWidget> {
  late DateTime _currentMonth;

  /// Internally track the first tap (anchor).
  String? _pendingStart;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.parse(widget.selectedDate);
  }

  @override
  void didUpdateWidget(covariant MiniCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent resets to a single date, clear pending state
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.rangeEndDate != widget.rangeEndDate) {
      if (widget.rangeEndDate == null) _pendingStart = null;
      // Scroll calendar to show the selected date's month
      final parsed = DateTime.tryParse(widget.selectedDate);
      if (parsed != null &&
          (parsed.year != _currentMonth.year ||
              parsed.month != _currentMonth.month)) {
        _currentMonth = DateTime(parsed.year, parsed.month, 1);
      }
    }
  }

  void _prevMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
  });

  void _nextMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
  });

  void _onDayTap(String dateStr) {
    if (_pendingStart == null) {
      // First tap — anchor start, clear range
      setState(() => _pendingStart = dateStr);
      widget.onRangeSelect(dateStr, null);
    } else {
      // Second tap — determine range direction
      final pendingStart = _pendingStart!;
      final start = DateTime.parse(pendingStart);
      final end = DateTime.parse(dateStr);

      if (start == end) {
        // Tapped the same day — single day selection
        setState(() => _pendingStart = null);
        widget.onRangeSelect(dateStr, null);
      } else if (end.isBefore(start)) {
        // Tapped earlier date — swap
        setState(() => _pendingStart = null);
        widget.onRangeSelect(dateStr, pendingStart);
      } else {
        // Normal forward range
        setState(() => _pendingStart = null);
        widget.onRangeSelect(pendingStart, dateStr);
      }
    }
  }

  bool _isInRange(DateTime date) {
    final start = DateTime.tryParse(widget.selectedDate);
    final end = widget.rangeEndDate != null
        ? DateTime.tryParse(widget.rangeEndDate!)
        : null;
    if (start == null || end == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return d.isAfter(s) && d.isBefore(e);
  }

  bool _isRangeStart(DateTime date) {
    final start = DateTime.tryParse(widget.selectedDate);
    if (start == null) return false;
    return date.year == start.year &&
        date.month == start.month &&
        date.day == start.day;
  }

  bool _isRangeEnd(DateTime date) {
    if (widget.rangeEndDate == null) return false;
    final end = DateTime.parse(widget.rangeEndDate!);
    return date.year == end.year &&
        date.month == end.month &&
        date.day == end.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF6366F1);
    final today = DateTime.now();

    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );
    final int startOffset = firstDayOfMonth.weekday - 1;
    final int totalDays = lastDayOfMonth.day;
    final int gridCount = startOffset + totalDays;

    final hasRange = widget.rangeEndDate != null;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _prevMonth,
              icon: Icon(
                Icons.chevron_left,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                // Quick "Today" chip inside the calendar header
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMonth = DateTime(today.year, today.month, 1);
                      _pendingStart = null;
                    });
                    final todayStr = DateFormat('yyyy-MM-dd').format(today);
                    widget.onRangeSelect(todayStr, null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Today',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: _nextMonth,
              icon: Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),

        // Range hint text
        if (_pendingStart != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Tap another date to select a range',
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else if (hasRange)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${DateFormat('d MMM').format(DateTime.parse(widget.selectedDate))} → ${DateFormat('d MMM').format(DateTime.parse(widget.rangeEndDate!))}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() => _pendingStart = null);
                    widget.onRangeSelect(widget.selectedDate, null);
                  },
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 4),

        // ── Weekday Labels ───────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),

        // ── Days Grid ────────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gridCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 0,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();

            final day = index - startOffset + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);

            final isStart = _isRangeStart(date);
            final isEnd = _isRangeEnd(date);
            final inRange = _isInRange(date);
            final isSelected = isStart || isEnd;
            final isPending = _pendingStart == dateStr;

            final isToday =
                date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            // Range highlight background — strip across the day cell
            Color? rangeBg;
            if (inRange) {
              rangeBg = accent.withValues(alpha: 0.12);
            }

            // Rounded ends for start/end of range
            BorderRadius cellRadius;
            if (isStart && hasRange) {
              cellRadius = const BorderRadius.horizontal(
                left: Radius.circular(8),
              );
            } else if (isEnd) {
              cellRadius = const BorderRadius.horizontal(
                right: Radius.circular(8),
              );
            } else if (inRange) {
              cellRadius = BorderRadius.zero;
            } else {
              cellRadius = BorderRadius.circular(8);
            }

            return GestureDetector(
              onTap: () => _onDayTap(dateStr),
              child: Container(
                decoration: BoxDecoration(
                  color: rangeBg,
                  borderRadius: inRange ? BorderRadius.zero : null,
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent
                        : (isPending
                              ? accent.withValues(alpha: 0.3)
                              : (isToday
                                    ? accent.withValues(alpha: 0.12)
                                    : Colors.transparent)),
                    borderRadius: cellRadius,
                    border: isToday && !isSelected && !isPending
                        ? Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Text(
                    day.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? (isToday
                                      ? const Color(0xFF818CF8)
                                      : inRange
                                      ? Colors.grey[200]
                                      : Colors.grey[300])
                                : (isToday
                                      ? const Color(0xFF4F46E5)
                                      : inRange
                                      ? const Color(0xFF4338CA)
                                      : Colors.grey[700])),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
