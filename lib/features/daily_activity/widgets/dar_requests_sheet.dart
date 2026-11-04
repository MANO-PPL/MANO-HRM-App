import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/daily_activity/core/dar_models.dart';
import 'package:flutter_application/features/daily_activity/widgets/dar_admin_controller.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class DarRequestsSheet extends StatefulWidget {
  final DarAdminController ctrl;

  const DarRequestsSheet({super.key, required this.ctrl});

  static Future<void> show(BuildContext context, DarAdminController ctrl) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DarRequestsSheet(ctrl: ctrl),
    );
  }

  @override
  State<DarRequestsSheet> createState() => _DarRequestsSheetState();
}

class _DarRequestsSheetState extends State<DarRequestsSheet> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: widget.ctrl,
      builder: (context, _) {
        final requests = widget.ctrl.filteredRequests;
        final pendingCount = widget.ctrl.pendingRequestsCount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            children: [
              // Header Drag Handle & Title
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: border, width: 1)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.assignment_turned_in_outlined,
                              color: Color(0xFF4F46E5), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Revision Requests',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (pendingCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.amber.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        '$pendingCount Pending',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                'Review past date edit submissions',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => widget.ctrl.fetchRequests(),
                          icon: Icon(Icons.refresh, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                          tooltip: 'Refresh',
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Tabs (All, Pending, Approved, Rejected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _filterChip('all', 'All (${widget.ctrl.requests.length})', isDark),
                    const SizedBox(width: 8),
                    _filterChip('pending', 'Pending ($pendingCount)', isDark),
                    const SizedBox(width: 8),
                    _filterChip('approved', 'Approved', isDark),
                    const SizedBox(width: 8),
                    _filterChip('rejected', 'Rejected', isDark),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Request List Content
              Expanded(
                child: widget.ctrl.isLoadingRequests
                    ? const Center(child: CircularProgressIndicator())
                    : requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No revision requests found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: requests.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) => _buildRequestCard(requests[i], isDark),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String key, String label, bool isDark) {
    final isSelected = widget.ctrl.requestStatusFilter == key;
    final activeBg = const Color(0xFF4F46E5);
    final inactiveBg = isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: () => widget.ctrl.setRequestStatusFilter(key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(DarRequestItem req, bool isDark) {
    Color statusColor;
    Color statusBg;
    switch (req.status) {
      case 'APPROVED':
        statusColor = const Color(0xFF10B981);
        statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFEF4444);
        statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        break;
      case 'PENDING':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        break;
    }

    final cardBorder = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1C2128) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Employee info and status badge
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                child: Text(
                  req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'U',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.userName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${req.userDept ?? "General"}  •  For ${req.requestDate}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  req.status,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          if (req.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reason: "${req.reason}"',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ],

          if (req.adminComment != null && req.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Admin Note: ${req.adminComment}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red[400],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Task Count comparison & Action buttons
          Row(
            children: [
              Text(
                'Proposed Tasks: ${req.proposedData.length}',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showReviewDialog(req),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                label: Text(
                  'Review Diff',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (req.status == 'PENDING') ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => _handleApprove(req),
                  icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
                  tooltip: 'Approve',
                ),
                IconButton(
                  onPressed: () => _promptReject(req),
                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 22),
                  tooltip: 'Reject',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(DarRequestItem req) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          title: Text(
            'Request Details - ${req.userName}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${req.requestDate}',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Reason: ${req.reason}',
                      style: GoogleFonts.poppins(fontSize: 12)),
                  const SizedBox(height: 12),
                  Text('PROPOSED TASKS (${req.proposedData.length}):',
                      style: GoogleFonts.poppins(
                          fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
                  const SizedBox(height: 6),
                  ...req.proposedData.map((task) {
                    final t = task is Map ? task : {};
                    final title = t['title'] ?? 'Untitled';
                    final sTime = t['start_time'] ?? t['startTime'] ?? '';
                    final eTime = t['end_time'] ?? t['endTime'] ?? '';
                    final desc = t['description'] ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(title.toString(),
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, fontSize: 12)),
                              const Spacer(),
                              Text('$sTime - $eTime',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10.5, color: Colors.grey)),
                            ],
                          ),
                          if (desc.toString().isNotEmpty)
                            Text(desc.toString(),
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            if (req.status == 'PENDING') ...[
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _promptReject(req);
                },
                child: const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _handleApprove(req);
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Approve'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _handleApprove(DarRequestItem req) async {
    final success = await widget.ctrl.approveRequest(req.requestId);
    if (mounted) {
      if (success) {
        context.showToast('Request #${req.requestId} approved successfully!', isSuccess: true);
      } else {
        context.showToast('Failed to approve request', isError: true);
      }
    }
  }

  void _promptReject(DarRequestItem req) {
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          title: Text(
            'Reject Request',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to reject this DAR revision request from ${req.userName}?',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await widget.ctrl.rejectRequest(
                  req.requestId,
                  comment: commentCtrl.text.trim().isNotEmpty ? commentCtrl.text.trim() : null,
                );
                if (mounted) {
                  if (success) {
                    context.showToast('Request rejected.', isSuccess: true);
                  } else {
                    context.showToast('Failed to reject request', isError: true);
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );
  }
}
