import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';

class ReportStatsBanner extends StatelessWidget {
  final ReportSummaryStats summary;
  final bool isCompact;

  const ReportStatsBanner({
    super.key,
    required this.summary,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      {
        'label': 'PRESENT',
        'value': '${summary.present}',
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.check_circle_outline,
      },
      {
        'label': 'ABSENT',
        'value': '${summary.absent}',
        'color': const Color(0xFFEF4444),
        'bg': const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.cancel_outlined,
      },
      {
        'label': 'LEAVE',
        'value': '${summary.leave}',
        'color': const Color(0xFF0284C7),
        'bg': const Color(0xFF0284C7).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.beach_access_outlined,
      },
      {
        'label': 'HALF DAY',
        'value': '${summary.halfDay}',
        'color': const Color(0xFF6366F1),
        'bg': const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.timelapse_outlined,
      },
      {
        'label': 'OVERTIME',
        'value': '${summary.overtimeHours.toStringAsFixed(1)}h',
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.more_time_outlined,
      },
      {
        'label': 'LATE MARKS',
        'value': '${summary.lateCount}',
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
        'icon': Icons.warning_amber_rounded,
      },
    ];

    if (isCompact) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 2.35,
        ),
        itemCount: items.length,
        itemBuilder: (context, idx) => _buildStatCard(items[idx], isDark, isSmall: true),
      );
    }

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildStatCard(item, isDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> item, bool isDark, {bool isSmall = false}) {
    final Color color = item['color'] as Color;
    final Color bg = item['bg'] as Color;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 12, vertical: isSmall ? 4 : 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 3.5 : 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item['icon'] as IconData, size: isSmall ? 12 : 18, color: color),
          ),
          SizedBox(width: isSmall ? 5 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['label'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 8 : 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['value'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 12.5 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
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

// [mod:2026-02-26T14:00:00+05:30]

// [upd:2026-05-04T11:30:00+05:30]

// [upd:2026-05-10T11:30:00+05:30]

// [rev:2026-08-24T08:30:00+05:30]
