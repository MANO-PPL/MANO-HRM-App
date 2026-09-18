import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';

class AdminLeaveListItem extends StatelessWidget {
  final LeaveRequest request;
  final bool isSelected;
  final VoidCallback onTap;

  const AdminLeaveListItem({
    super.key,
    required this.request,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = request.status.toLowerCase();

    final Color statusColor;
    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }

    final initial = (request.userName != null && request.userName!.isNotEmpty)
        ? request.userName![0].toUpperCase()
        : 'U';

    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
              width: 4,
            ),
            bottom: BorderSide(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFF1F5F9),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  backgroundImage: (request.userAvatar != null &&
                          request.userAvatar!.startsWith('http'))
                      ? NetworkImage(request.userAvatar!)
                      : null,
                  child: (request.userAvatar == null ||
                          !request.userAvatar!.startsWith('http'))
                      ? Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName ?? 'Employee',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.userEmail ?? 'No email',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Leave Type Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.leaveType,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Date & Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(request.startDate),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Text(
                  request.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
