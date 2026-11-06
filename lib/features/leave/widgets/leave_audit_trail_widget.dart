import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LeaveAuditTrailWidget extends StatelessWidget {
  final List<Map<String, dynamic>> auditTrail;
  final bool compact;

  const LeaveAuditTrailWidget({
    super.key,
    required this.auditTrail,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (auditTrail.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                'Audit Trail & History',
                style: GoogleFonts.inter(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: auditTrail.length,
            itemBuilder: (context, index) {
              final item = auditTrail[index];
              final isLast = index == auditTrail.length - 1;
              return _buildTimelineItem(context, item, isLast, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    Map<String, dynamic> item,
    bool isLast,
    bool isDark,
  ) {
    final action = (item['action']?.toString() ?? 'submitted').toLowerCase();
    final byName = item['by_name']?.toString() ?? item['by']?.toString() ?? 'User';
    final rawAt = item['at']?.toString();
    DateTime? date;
    if (rawAt != null) {
      date = DateTime.tryParse(rawAt)?.toLocal();
    }
    final comments = item['comments']?.toString();

    Color dotColor;
    String actionTitle;
    IconData actionIcon;

    switch (action) {
      case 'approved':
        dotColor = const Color(0xFF10B981);
        actionTitle = 'Request Approved';
        actionIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        dotColor = const Color(0xFFEF4444);
        actionTitle = 'Request Rejected';
        actionIcon = Icons.cancel_rounded;
        break;
      case 'cancelled':
      case 'withdrawn':
        dotColor = const Color(0xFFF59E0B);
        actionTitle = 'Request Withdrawn';
        actionIcon = Icons.remove_circle_outline_rounded;
        break;
      case 'submitted':
      default:
        dotColor = const Color(0xFF6366F1);
        actionTitle = 'Request Submitted';
        actionIcon = Icons.send_rounded;
        break;
    }

    final formattedDate = date != null
        ? DateFormat('d MMM yyyy, h:mm a').format(date)
        : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      actionIcon,
                      size: 9,
                      color: dotColor,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Event content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          actionTitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (formattedDate.isNotEmpty)
                        Text(
                          formattedDate,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by $byName',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  if (comments != null && comments.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '"$comments"',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
