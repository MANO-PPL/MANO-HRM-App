import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/features/daily_activity/core/dar_models.dart';

class DailyActivityDaySnapshotCard extends StatelessWidget {
  final String date;
  final List<DarItem> items;
  final Map<String, dynamic>? attendance;
  final String? holidayName;
  final bool isDark;
  final String emptyMessage;
  final int maxVisibleTasks;

  const DailyActivityDaySnapshotCard({
    super.key,
    required this.date,
    required this.items,
    required this.attendance,
    required this.holidayName,
    required this.isDark,
    this.emptyMessage = 'No tasks logged for this date.',
    this.maxVisibleTasks = 3,
  });

  String _formatPunchTime(dynamic value) {
    if (value == null) return '--:--';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasTimedIn = attendance != null && attendance!['hasTimedIn'] == true;
    final punchIn = _formatPunchTime(attendance?['timeIn']);
    final punchOut = _formatPunchTime(attendance?['timeOut']);
    final parsedDate = DateTime.parse(date);
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final isHoliday = holidayName != null;
    final isAbsent = !hasTimedIn && !isHoliday && parsedDate.isBefore(startOfToday);

    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('d MMMM yyyy').format(parsedDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Focused day snapshot',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHoliday)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      holidayName!,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  )
                else if (isAbsent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ABSENT',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                    label: 'TIME IN',
                    value: punchIn,
                    accent: const Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeTile(
                    label: 'TIME OUT',
                    value: punchOut,
                    accent: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// [upd:2026-04-15T11:30:00+05:30]
