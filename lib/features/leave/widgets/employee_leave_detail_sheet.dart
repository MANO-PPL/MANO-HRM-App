import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/leave/widgets/attachment_viewer_dialog.dart';

class EmployeeLeaveDetailSheet extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback? onWithdrawn;

  const EmployeeLeaveDetailSheet({
    super.key,
    required this.leave,
    this.onWithdrawn,
  });

  static void show(BuildContext context, LeaveRequest leave, {VoidCallback? onWithdrawn}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeLeaveDetailSheet(
        leave: leave,
        onWithdrawn: onWithdrawn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = leave.status.toLowerCase();

    final Color accentColor;
    final Color pillBg;
    final Color pillText;
    final IconData statusIcon;

    if (status == 'approved') {
      accentColor = const Color(0xFF10B981);
      pillBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      pillText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      accentColor = const Color(0xFFEF4444);
      pillBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      pillText = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
      statusIcon = Icons.cancel_rounded;
    } else {
      accentColor = const Color(0xFFF59E0B);
      pillBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      pillText = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      statusIcon = Icons.schedule_rounded;
    }

    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final appliedFormat = DateFormat('MMM d, yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Details',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Request #${leave.id}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Status Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accentColor.withValues(alpha: isDark ? 0.18 : 0.1),
                            accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              statusIcon,
                              color: accentColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: pillBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: pillText,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        leave.status.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: pillText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${leave.durationDays} Day${leave.durationDays > 1 ? 's' : ''} Leave',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  leave.policyName ?? leave.leaveType,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Info Breakdown Table
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildRow(
                            'Leave Type',
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  leave.leaveType,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (leave.leaveCode != null && leave.leaveCode!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      leave.leaveCode!,
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
                            isDark,
                          ),
                          _buildDivider(isDark),
                          _buildRow(
                            'Start Date',
                            Text(
                              dateFormat.format(leave.startDate),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.grey.shade800,
                              ),
                            ),
                            isDark,
                          ),
                          _buildDivider(isDark),
                          _buildRow(
                            'End Date',
                            Text(
                              dateFormat.format(leave.endDate),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.grey.shade800,
                              ),
                            ),
                            isDark,
                          ),
                          _buildDivider(isDark),
                          _buildRow(
                            'Duration',
                            Text(
                              '${leave.durationDays} Day${leave.durationDays > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            isDark,
                          ),
                          _buildDivider(isDark),
                          _buildRow(
                            'Applied On',
                            Text(
                              appliedFormat.format(leave.appliedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.grey.shade800,
                              ),
                            ),
                            isDark,
                          ),
                          if (leave.status == 'approved' && leave.payType != null) ...[
                            _buildDivider(isDark),
                            _buildRow(
                              'Pay Type',
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: leave.payType == 'Paid'
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                                      : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  leave.payType!,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: leave.payType == 'Paid'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              isDark,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Reason Section
                    Text(
                      'Reason',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        leave.reason.isNotEmpty ? leave.reason : 'No reason provided.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),

                    // Admin Note Section (if present)
                    if (leave.adminComment != null && leave.adminComment!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Admin Note',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.3 : 0.25),
                          ),
                        ),
                        child: Text(
                          leave.adminComment!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    // Attachments Section
                    if (leave.attachments.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Attachments (${leave.attachments.length})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...leave.attachments.map((att) {
                        final filename = att.fileKey.split('/').last;
                        return InkWell(
                          onTap: () => AttachmentViewerDialog.show(context, att),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.attach_file_rounded,
                                  size: 18,
                                  color: Color(0xFF6366F1),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    filename,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Footer Action: Withdraw Button for Pending Requests
            if (leave.status == 'pending')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await CustomDialog.show(
                        context: context,
                        title: 'Withdraw Request?',
                        message: 'Are you sure you want to withdraw this leave request? This action cannot be undone.',
                        positiveButtonText: 'Withdraw',
                        onPositivePressed: () {},
                        isDestructive: true,
                        icon: Icons.delete_outline_rounded,
                        iconColor: Colors.red,
                      );

                      if (confirm == true && context.mounted) {
                        try {
                          await context.read<LeaveProvider>().withdrawRequest(leave.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            context.showToast('Request withdrawn successfully.', isSuccess: true);
                            onWithdrawn?.call();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            context.showToast('Failed to withdraw request: $e', isError: true);
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.06),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      'Withdraw Request',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, Widget valueWidget, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
    );
  }
}
