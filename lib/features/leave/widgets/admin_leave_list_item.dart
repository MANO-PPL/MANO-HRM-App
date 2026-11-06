import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/shared/widgets/pfp_viewer_dialog.dart';

class AdminLeaveListItem extends StatelessWidget {
  final LeaveRequest request;
  final bool isSelected;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? margin;

  const AdminLeaveListItem({
    super.key,
    required this.request,
    this.isSelected = false,
    required this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = request.status.toLowerCase();

    final Color statusColor;
    final Color statusBg;
    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    }

    final initial = (request.userName != null && request.userName!.isNotEmpty)
        ? request.userName![0].toUpperCase()
        : 'U';

    final code = request.leaveCode ??
        request.leaveType.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join('').toUpperCase();

    final String dateRangeStr;
    final isSameDay = request.startDate.year == request.endDate.year &&
        request.startDate.month == request.endDate.month &&
        request.startDate.day == request.endDate.day;
    if (isSameDay) {
      dateRangeStr = DateFormat('d MMM yyyy').format(request.startDate);
    } else if (request.startDate.year == request.endDate.year &&
        request.startDate.month == request.endDate.month) {
      dateRangeStr =
          '${DateFormat('d').format(request.startDate)} – ${DateFormat('d MMM yyyy').format(request.endDate)}';
    } else if (request.startDate.year == request.endDate.year) {
      dateRangeStr =
          '${DateFormat('d MMM').format(request.startDate)} – ${DateFormat('d MMM yyyy').format(request.endDate)}';
    } else {
      dateRangeStr =
          '${DateFormat('d MMM yy').format(request.startDate)} – ${DateFormat('d MMM yy').format(request.endDate)}';
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF))
            : (isDark ? const Color(0xFF161B22) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Employee Info + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        PfpViewerDialog.show(
                          context,
                          imageUrl: request.userAvatar,
                          name: request.userName ?? 'Employee',
                          subtitle: request.userDesignation ?? request.userEmail,
                          heroTag: 'admin_leave_avatar_${request.id}',
                        );
                      },
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.userName ?? 'Employee',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            request.userDesignation ?? request.userEmail ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                // Middle Row: Leave Type + Duration + Date Range (Responsive & Overflow-free)
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code.isNotEmpty ? '${request.leaveType} [$code]' : request.leaveType,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${request.durationDays} ${request.durationDays > 1 ? "Days" : "Day"}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateRangeStr,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Reason snippet
                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${request.reason}"',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

