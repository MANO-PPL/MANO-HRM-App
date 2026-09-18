import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/widgets/employee_leave_detail_sheet.dart';

class LeaveHistoryItem extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const LeaveHistoryItem({
    super.key,
    required this.request,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = request.status.toLowerCase();

    final Color statusPillBg;
    final Color statusTextColor;
    final Color statusDotColor;

    if (status == 'approved') {
      statusPillBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      statusTextColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      statusDotColor = const Color(0xFF10B981);
    } else if (status == 'rejected') {
      statusPillBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      statusTextColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      statusDotColor = const Color(0xFFEF4444);
    } else {
      statusPillBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      statusTextColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      statusDotColor = const Color(0xFFF59E0B);
    }

    final dateFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    final appliedFormat = DateFormat('MMM d, yyyy');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => EmployeeLeaveDetailSheet.show(context, request),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  request.policyName ?? request.leaveType,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (request.leaveCode != null && request.leaveCode!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    request.leaveCode!,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (request.policyName != null && request.policyName != request.leaveType) ...[
                            const SizedBox(height: 2),
                            Text(
                              request.leaveType,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusPillBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            request.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Middle Row: Duration & Dates
                Row(
                  children: [
                    const Icon(Icons.date_range_outlined, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      '${request.durationDays} Day${request.durationDays > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '(${dateFormat.format(request.startDate)} - ${endFormat.format(request.endDate)})',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.reason,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Bottom Row: Applied On & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Applied: ${appliedFormat.format(request.appliedAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                      ),
                    ),

                    Row(
                      children: [
                        Text(
                          'View Details →',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        if (request.status.toLowerCase() == 'pending' && onDelete != null) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: isDark ? Colors.red.shade400 : Colors.red.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
