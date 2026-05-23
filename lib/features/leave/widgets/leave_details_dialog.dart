import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/features/leave/models/leave_request_model.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class LeaveDetailsDialog extends StatefulWidget {
  final LeaveRequest request;
  final double width;
  final EdgeInsets padding;
  final VoidCallback? onWithdraw;
  
  // Admin Review Mode
  final bool isReviewMode;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const LeaveDetailsDialog({
    super.key, 
    required this.request,
    this.width = 400,
    this.padding = const EdgeInsets.all(24),
    this.onWithdraw,
    this.isReviewMode = false,
    this.onApprove,
    this.onReject,
  });

  static Future<void> showMobile(BuildContext context, {
    required LeaveRequest request, 
    VoidCallback? onWithdraw,
    bool isReviewMode = false,
    VoidCallback? onApprove,
    VoidCallback? onReject,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: LeaveDetailsDialog(
          request: request,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          onWithdraw: onWithdraw,
          isReviewMode: isReviewMode,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ),
    );
  }

  static Future<void> showPortrait(BuildContext context, {required LeaveRequest request, VoidCallback? onWithdraw}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: LeaveDetailsDialog(
          request: request,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          onWithdraw: onWithdraw,
        ),
      ),
    );
  }

  static Future<void> showLandscape(BuildContext context, {required LeaveRequest request, VoidCallback? onWithdraw}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: LeaveDetailsDialog(
          request: request,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          onWithdraw: onWithdraw,
        ),
      ),
    );
  }

  @override
  State<LeaveDetailsDialog> createState() => _LeaveDetailsDialogState();
}

class _LeaveDetailsDialogState extends State<LeaveDetailsDialog> {
  late final TextEditingController _adminCommentController;
  String _payType = 'Paid';
  int _payPercentage = 100;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _adminCommentController = TextEditingController(text: widget.request.adminComment ?? '');
    _payType = widget.request.payType ?? 'Paid';
    _payPercentage = (widget.request.payPercentage ?? 100).toInt();
  }

  @override
  void dispose() {
    _adminCommentController.dispose();
    super.dispose();
  }

  // Method to open attachment
  Future<void> _openAttachment(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening document...'), duration: Duration(seconds: 1)),
      );
      
      final file = await DefaultCacheManager().getSingleFile(url);
      final result = await OpenFilex.open(file.path);
      
      if (result.type != ResultType.done) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final startDateStr = DateFormat('MM/dd/yyyy').format(widget.request.startDate);
    final endDateStr = DateFormat('MM/dd/yyyy').format(widget.request.endDate);
    final appliedOnStr = DateFormat('MM/dd/yyyy').format(widget.request.appliedAt);
    final duration = widget.request.endDate.difference(widget.request.startDate).inDays + 1;

    Color statusColor = Colors.grey;
    final status = widget.request.status.toLowerCase().trim();
    if (status == 'approved') statusColor = const Color(0xFF22C55E);
    if (status == 'rejected') statusColor = const Color(0xFFEF4444);
    if (status == 'pending') statusColor = const Color(0xFFF59E0B);

    final highlightColor = const Color(0xFF6366F1); // Blueish

    final content = Container(
      width: widget.width,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: widget.width == double.infinity
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.width == double.infinity) ...[
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
            // Header Section
            _buildHeader(context, statusColor, appliedOnStr),
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black12),
            const SizedBox(height: 16),

            // Scrollable part
            widget.width == double.infinity
                ? Expanded(
                    child: SingleChildScrollView(
                      child: _buildDetailsColumn(context, startDateStr, endDateStr, duration, highlightColor, status),
                    ),
                  )
                : SingleChildScrollView(
                    child: _buildDetailsColumn(context, startDateStr, endDateStr, duration, highlightColor, status),
                  ),
          ],
        ),
      ),
    );

    if (widget.width == double.infinity) {
      // Bottom sheet keyboard handling
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: content,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: content,
    );
  }

  Widget _buildDetailsColumn(
    BuildContext context,
    String startDateStr,
    String endDateStr,
    int duration,
    Color highlightColor,
    String status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave Details Section
        _buildSectionTitle(context, "LEAVE DETAILS"),
        const SizedBox(height: 12),
        _buildInfoBox(context, "Type", widget.request.leaveType, isFullWidth: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoBox(context, "From", startDateStr)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoBox(context, "To", endDateStr)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDurationBox(context, duration, highlightColor),

        const SizedBox(height: 24),

        // Justification Section
        _buildSectionTitle(context, "JUSTIFICATION & REMARKS"),
        const SizedBox(height: 12),
        _buildReasonBox(context, widget.request.reason),

        // Attachments Section
        if (widget.request.attachments.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle(context, "ATTACHMENTS"),
          const SizedBox(height: 12),
          ...widget.request.attachments.map((att) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () => _openAttachment(att.fileUrl, att.fileKey),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20, color: highlightColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        att.fileKey.split('/').last,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          )).toList(),
        ],

        // Audit Trail (If not pending and has review info)
        if (widget.request.status.toLowerCase() != 'pending' && widget.request.reviewedBy != null) ...[
          const SizedBox(height: 24),
          _buildSectionTitle(context, "REVIEW DETAILS"),
          const SizedBox(height: 12),
          _buildReviewBox(context),
        ],

        const SizedBox(height: 24),

        // Admin Action or User Actions
        if (widget.isReviewMode && status == 'pending')
          _buildAdminActionSection(context)
        else
          _buildUserActionSection(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color statusColor, String appliedDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? avatarUrl = widget.request.userAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      avatarUrl = avatarUrl.startsWith('/') ? '${ApiConstants.baseUrl}$avatarUrl' : '${ApiConstants.baseUrl}/$avatarUrl';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? null
                    : Text(
                        (widget.request.userName ?? 'User').isNotEmpty ? (widget.request.userName ?? 'User')[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF4F46E5),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Leave Request #${widget.request.id != 0 ? widget.request.id : 'Pending'}",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF30363D),
                      ),
                    ),
                    Text(
                      "By ${widget.request.userName ?? 'User'}",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.request.status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Applied: $appliedDate",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String label, String value, {bool isFullWidth = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0D1117),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationBox(BuildContext context, int days, Color highlightColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlightColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlightColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Duration", style: GoogleFonts.poppins(fontSize: 11, color: highlightColor.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(
            "$days Days",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: highlightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonBox(BuildContext context, String reason) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: isDark ? Colors.white24 : const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reason", style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  "\"$reason\"",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : const Color(0xFF30363D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewedAt = widget.request.reviewedAt != null ? DateFormat('MM/dd/yyyy').format(widget.request.reviewedAt!) : '';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Reviewed By: ${widget.request.reviewedBy ?? 'Admin'}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              Text(reviewedAt, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ],
          ),
          if (widget.request.adminComment != null && widget.request.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Remarks: \"${widget.request.adminComment}\"",
              style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminActionSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, "ADMIN ACTION"),
        const SizedBox(height: 12),
        
        // Pay details for approval
        Row(
          children: [
            Expanded(
              child: _buildAdminDropdown(
                context, 
                "Pay Type", 
                _payType, 
                ['Paid', 'Unpaid', 'Partial'], 
                (val) => setState(() {
                  _payType = val!;
                  if (val == 'Paid') _payPercentage = 100;
                  if (val == 'Unpaid') _payPercentage = 0;
                })
              ),
            ),
            if (_payType == 'Partial') ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdminInfoBox(context, "Pay %", "$_payPercentage%"),
              ),
            ],
          ],
        ),
        
        if (_payType == 'Partial') 
          Slider(
            value: _payPercentage.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (val) => setState(() => _payPercentage = val.round()),
          ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _adminCommentController,
            maxLines: 2,
            style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Add reason (required for approval/rejection)...",
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _processAction('Approved'),
                icon: _isProcessing 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 16),
                label: const Text("Approve"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _processAction('Rejected'),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text("Reject"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminDropdown(BuildContext context, String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF30363D) : Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInfoBox(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildUserActionSection(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                foregroundColor: Colors.grey,
              ),
              child: const Text("Close"),
            ),
          ),

        ],
      ),
    );
  }

  Future<void> _processAction(String status) async {
    if ((status.toLowerCase() == 'approved' ||
            status.toLowerCase() == 'rejected') &&
        _adminCommentController.text.trim().isEmpty) {
      context.showToast("It needs a reason.", isWarning: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await context.read<LeaveProvider>().reviewRequest(
        widget.request.id,
        status: status, // "Approved" or "Rejected"
        comment: _adminCommentController.text,
        payType: _payType,
        payPercentage: _payPercentage,
      );
      if (mounted) {
        Navigator.pop(context);
        if (status.toLowerCase() == 'approved' && widget.onApprove != null) widget.onApprove!();
        if (status.toLowerCase() == 'rejected' && widget.onReject != null) widget.onReject!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isProcessing = false);
      }
    }
  }
}
