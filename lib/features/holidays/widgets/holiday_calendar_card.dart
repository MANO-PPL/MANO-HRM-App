import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/holidays/core/holiday_model.dart';

class HolidayCalendarCard extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime? selectedDate;
  final List<Holiday> holidays;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime>? onDateSelected;
  final VoidCallback onTodayPressed;

  const HolidayCalendarCard({
    super.key,
    required this.currentMonth,
    this.selectedDate,
    required this.holidays,
    required this.onMonthChanged,
    this.onDateSelected,
    required this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Calculate 42 days (6 rows x 7 days) starting on Sunday
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final leadingDays = firstDayOfMonth.weekday % 7; // Sunday is 7 in Dart, 7 % 7 = 0
    final gridStartDate = firstDayOfMonth.subtract(Duration(days: leadingDays));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Month / Year Header + < TODAY > Button Group
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM\nyyyy').format(currentMonth),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildNavigationGroup(isDark),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Weekday Header Row (SUN - SAT)
          Row(
            children: const [
              _WeekdayCell(label: 'SUN'),
              _WeekdayCell(label: 'MON'),
              _WeekdayCell(label: 'TUE'),
              _WeekdayCell(label: 'WED'),
              _WeekdayCell(label: 'THU'),
              _WeekdayCell(label: 'FRI'),
              _WeekdayCell(label: 'SAT'),
            ],
          ),

          const SizedBox(height: 12),

          // 3. 42-day Month Grid
          Column(
            children: List.generate(6, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: List.generate(7, (colIndex) {
                    final dayIndex = rowIndex * 7 + colIndex;
                    final cellDate = gridStartDate.add(Duration(days: dayIndex));
                    return Expanded(
                      child: _buildDayCell(cellDate, now, isDark),
                    );
                  }),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
          Divider(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            height: 1,
          ),
          const SizedBox(height: 14),

          // 4. Legend Row: ■ PUBLIC    ■ OPTIONAL
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: const Color(0xFF9333EA), // Purple
                label: 'PUBLIC',
                isDark: isDark,
              ),
              const SizedBox(width: 20),
              _buildLegendItem(
                color: const Color(0xFFF59E0B), // Orange/Amber
                label: 'OPTIONAL',
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationGroup(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Previous Month (<)
          InkWell(
            onTap: () {
              final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
              onMonthChanged(prevMonth);
            },
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Icon(
                Icons.chevron_left,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),

          Container(
            width: 1,
            height: 16,
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
          ),

          // TODAY Button
          InkWell(
            onTap: onTodayPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'TODAY',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),

          Container(
            width: 1,
            height: 16,
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
          ),

          // Next Month (>)
          InkWell(
            onTap: () {
              final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
              onMonthChanged(nextMonth);
            },
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime cellDate, DateTime now, bool isDark) {
    final isCurrentMonth = cellDate.month == currentMonth.month;
    final isToday = cellDate.year == now.year &&
        cellDate.month == now.month &&
        cellDate.day == now.day;
    final isSelected = selectedDate != null &&
        cellDate.year == selectedDate!.year &&
        cellDate.month == selectedDate!.month &&
        cellDate.day == selectedDate!.day;

    final dateStr = DateFormat('yyyy-MM-dd').format(cellDate);
    final dayHolidays = holidays.where((h) => h.date == dateStr).toList();
    final hasPublic = dayHolidays.any((h) => h.type.toLowerCase() == 'public');
    final hasOptional = dayHolidays.any((h) => h.type.toLowerCase() == 'optional');

    Color textColor;
    if (isToday) {
      textColor = Colors.white;
    } else if (isCurrentMonth) {
      textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    } else {
      textColor = isDark ? const Color(0xFF484F58) : const Color(0xFF94A3B8);
    }

    return InkWell(
      onTap: () {
        if (onDateSelected != null) {
          onDateSelected!(cellDate);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday
              ? const Color(0xFF4F46E5) // Solid indigo circle matching screenshot
              : (isSelected
                  ? (isDark ? const Color(0xFF21262D) : const Color(0xFFE0E7FF))
                  : Colors.transparent),
          border: isSelected && !isToday
              ? Border.all(color: const Color(0xFF6366F1), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cellDate.day}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (hasPublic || hasOptional) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPublic)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9333EA),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (hasPublic && hasOptional) const SizedBox(width: 2),
                  if (hasOptional)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  final String label;

  const _WeekdayCell({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
