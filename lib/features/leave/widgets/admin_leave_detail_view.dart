import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/leave/widgets/attachment_viewer_dialog.dart';

class AdminLeaveDetailView extends StatefulWidget {
  final LeaveRequest? request;
  final VoidCallback? onStatusUpdated;

  const AdminLeaveDetailView({
    super.key,
    this.request,
    this.onStatusUpdated,
  });

  @override
  State<AdminLeaveDetailView> createState() => _AdminLeaveDetailViewState();
}

class _AdminLeaveDetailViewState extends State<AdminLeaveDetailView> {
  String _payType = 'Paid';
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;
  bool _attachmentsExpanded = true;

  @override
  void didUpdateWidget(covariant AdminLeaveDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request?.id != widget.request?.id) {
      _remarksController.clear();
      _payType = 'Paid';
      _attachmentsExpanded = true;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String status) async {
    final req = widget.request;
    if (req == null) return;

    final isReject = status.toLowerCase() == 'rejected';
    final remarks = _remarksController.text.trim();

    if (isReject && remarks.isEmpty) {
      context.showToast('Please add remarks for rejection.', isWarning: true);
      return;
    }

    final confirmed = await CustomDialog.show(
      context: context,
      title: '$status Leave Request?',
      message: 'Are you sure you want to mark request #${req.id} as $status?',
      positiveButtonText: status,
      onPositivePressed: () {},
      isDestructive: isReject,
      icon: isReject ? Icons.cancel_outlined : Icons.check_circle_outline,
      iconColor: isReject ? Colors.red : Colors.green,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await context.read<LeaveProvider>().reviewRequest(
            req.id,
            status: status,
            comment: remarks.isNotEmpty ? remarks : null,
            payType: _payType,
            payPercentage: _payType == 'Paid' ? 100 : 0,
          );

      if (mounted) {
        context.showToast('Leave request ${status.toLowerCase()} successfully.', isSuccess: true);
        widget.onStatusUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Failed to update request: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;

    if (req == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Select a request to view details',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final status = req.status.toLowerCase();
    final Color statusColor;
    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }

    final initial = (req.userName != null && req.userName!.isNotEmpty)
        ? req.userName![0].toUpperCase()
        : 'U';

    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final appliedFormat = DateFormat('MMM d, yyyy');

    final provider = context.watch<LeaveProvider>();
    final employeeBalances = provider.selectedEmployeeBalances;
    final isLoadingBalances = provider.isLoadingEmployeeBalances;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                backgroundImage: (req.userAvatar != null && req.userAvatar!.startsWith('http'))
                    ? NetworkImage(req.userAvatar!)
                    : null,
                child: (req.userAvatar == null || !req.userAvatar!.startsWith('http'))
                    ? Text(
                        initial,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leave Request #${req.id}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${req.userName ?? 'Employee'} • Applied on ${appliedFormat.format(req.appliedAt)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  req.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Consolidated Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEAVE TYPE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req.leaveType,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${req.durationDays} Days Duration',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FROM',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(req.startDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TO',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(req.endDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  'REASON',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  req.reason.isNotEmpty ? req.reason : 'No reason provided.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Employee Leave Balances Breakdown
          Text(
            "Employee's Leave Balances",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          if (isLoadingBalances)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (employeeBalances.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No balance records found for this employee.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: employeeBalances.map((bal) {
                final type = bal['leave_type']?.toString() ?? 'Leave';
                final available = bal['available']?.toString() ?? '0';
                final used = bal['used']?.toString() ?? '0';

                return Container(
                  width: 140,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$available days left',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      Text(
                        '$used used',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Attachments Section
          if (req.attachments.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _attachmentsExpanded = !_attachmentsExpanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(
                          '${req.attachments.length} Attachments',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _attachmentsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
            if (_attachmentsExpanded) ...[
              const SizedBox(height: 8),
              ...req.attachments.map((att) {
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
                        const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFF6366F1)),
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
                        const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
          ],

          const Divider(),
          const SizedBox(height: 10),

          // Admin Action Card
          if (status == 'pending') ...[
            Text(
              'Admin Action',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // Pay Type Radio Buttons
            Text(
              'Pay Type',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPayTypeRadio('Paid', 'Paid Leave', isDark),
                const SizedBox(width: 20),
                _buildPayTypeRadio('Unpaid', 'Unpaid Leave', isDark),
              ],
            ),

            const SizedBox(height: 14),

            // Remarks Textarea
            Text(
              'Remarks',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add remarks (required for rejection)...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),

            const SizedBox(height: 16),

            // Approve / Reject Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _handleAction('Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(
                      'Approve',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _handleAction('Rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Status Summary for Reviewed Request
            Text(
              'Review Details',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pay Status',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: req.payType == 'Paid'
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          req.payType ?? 'Unspecified',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: req.payType == 'Paid'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Admin Remarks',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.adminComment != null && req.adminComment!.isNotEmpty
                        ? req.adminComment!
                        : 'No remarks provided.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayTypeRadio(String value, String label, bool isDark) {
    final isSelected = _payType == value;
    return InkWell(
      onTap: () => setState(() => _payType = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? Colors.white38 : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
