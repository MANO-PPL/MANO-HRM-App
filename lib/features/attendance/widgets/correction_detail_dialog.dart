import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/features/attendance/core/attendance_service.dart';
import 'package:flutter_application/features/attendance/widgets/visual_correction_timeline.dart';
import 'package:flutter_application/features/attendance/widgets/correction_document_card.dart';
import 'package:flutter_application/features/attendance/widgets/correction_reject_dialog.dart';
import 'package:flutter_application/shared/models/user_model.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// Detailed view of a correction request with Visual 24h Timeline, Supporting Document Proof,
/// Stated Justification, Audit Trail, and Admin Actions (Approve, Reject with Presets, Manual Override).
/// Directly mirroring `CorrectionRequestsTab.jsx` from Attendance-Web.
class CorrectionDetailDialog extends StatefulWidget {
  final AttendanceCorrectionRequest request;
  final VoidCallback onStatusChanged;
  final bool isBottomSheet;
  final bool isEmbedded;
  final VoidCallback? onClose;

  const CorrectionDetailDialog({
    super.key,
    required this.request,
    required this.onStatusChanged,
    this.isBottomSheet = false,
    this.isEmbedded = false,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    required AttendanceCorrectionRequest request,
    required VoidCallback onStatusChanged,
  }) async {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 680 : double.infinity,
        maxHeight: size.height * 0.94,
      ),
      builder: (context) => CorrectionDetailDialog(
        request: request,
        onStatusChanged: onStatusChanged,
        isBottomSheet: true,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<CorrectionDetailDialog> createState() => _CorrectionDetailDialogState();
}

class _CorrectionDetailDialogState extends State<CorrectionDetailDialog> {
  late AttendanceService _service;
  bool _isLoading = false;
  bool _isFetching = true;
  AttendanceCorrectionRequest? _fullRequest;

  // Manual Override State
  bool _isOverride = false;
  List<Map<String, dynamic>> _overrideSessions = [];

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);

    _initOverrideSessionsFromRequest(widget.request);
    _fetchRequestDetails();
  }

  void _initOverrideSessionsFromRequest(AttendanceCorrectionRequest req) {
    if (req.sessions.isNotEmpty) {
      _overrideSessions = List<Map<String, dynamic>>.from(req.sessions);
    } else if (req.timeIn != null || req.timeOut != null) {
      _overrideSessions = [
        {
          'time_in': req.timeIn ?? '',
          'time_out': req.timeOut ?? '',
          'punch_type': 'regular',
        }
      ];
    } else {
      _overrideSessions = [];
    }
  }

  Future<void> _fetchRequestDetails() async {
    try {
      final detail = await _service.getCorrectionRequestDetail(widget.request.id);
      if (mounted) {
        setState(() {
          _fullRequest = detail;
          _isFetching = false;
          _initOverrideSessionsFromRequest(detail);
        });
      }
    } catch (e) {
      debugPrint("Error fetching correction detail: $e");
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _handleApprove() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, String>>? overrideSessionsToSend;
      if (_isOverride && _overrideSessions.isNotEmpty) {
        overrideSessionsToSend = _overrideSessions.map<Map<String, String>>((s) {
          final inT = s['time_in']?.toString() ?? '';
          final outT = s['time_out']?.toString() ?? '';
          return {
            'time_in': inT.length == 5 ? '$inT:00' : inT,
            'time_out': outT.length == 5 ? '$outT:00' : outT,
          };
        }).toList();
      }

      await _service.processCorrectionRequest(
        widget.request.id,
        status: 'approved',
        reviewComments: _isOverride ? 'Approved with manual override' : 'Approved by administrator',
        sessions: overrideSessionsToSend,
      );

      if (!mounted) return;
      if (!widget.isEmbedded) Navigator.pop(context);
      widget.onStatusChanged();
      context.showToast(
        _isOverride ? "Correction approved with manual override!" : "Correction request approved successfully!",
        isSuccess: true,
      );
    } catch (e) {
      if (mounted) {
        context.showToast('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject(String reason) async {
    setState(() => _isLoading = true);
    try {
      await _service.processCorrectionRequest(
        widget.request.id,
        status: 'rejected',
        reviewComments: reason,
      );

      if (!mounted) return;
      if (!widget.isEmbedded) Navigator.pop(context);
      widget.onStatusChanged();
      context.showToast("Correction request has been rejected.", isSuccess: true);
    } catch (e) {
      if (mounted) {
        context.showToast('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openRejectDialog(AttendanceCorrectionRequest req) async {
    await CorrectionRejectDialog.show(
      context,
      userName: req.userName,
      requestDate: req.requestDate,
      onConfirm: _handleReject,
    );
  }

  bool _isUserMatch(AttendanceCorrectionRequest r, User? user) {
    if (user == null) return false;
    final rUid = r.userId.trim().toLowerCase();
    final rEmpId = (r.employeeId ?? '').trim().toLowerCase();
    final rUname = r.userName.trim().toLowerCase();

    final myId = user.id.trim().toLowerCase();
    final myEmpId = user.employeeId.trim().toLowerCase();
    final myUsername = user.username.trim().toLowerCase();
    final myName = user.name.trim().toLowerCase();

    if (rUid.isNotEmpty) {
      if (myId.isNotEmpty && rUid == myId) return true;
      if (myEmpId.isNotEmpty && rUid == myEmpId) return true;
      if (myUsername.isNotEmpty && rUid == myUsername) return true;
    }

    if (rEmpId.isNotEmpty) {
      if (myId.isNotEmpty && rEmpId == myId) return true;
      if (myEmpId.isNotEmpty && rEmpId == myEmpId) return true;
      if (myUsername.isNotEmpty && rEmpId == myUsername) return true;
    }

    if (rUname.isNotEmpty && rUname != 'unknown' && myName.isNotEmpty && rUname == myName) {
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = _fullRequest ?? widget.request;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.user;
    final isOwnRequest = _isUserMatch(req, currentUser);
    final isAdmin = (currentUser?.isAdmin ?? false) && !isOwnRequest;
    final isPending = req.status == RequestStatus.pending;

    String? avatarUrl = req.userAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      avatarUrl = avatarUrl.startsWith('/')
          ? '${ApiConstants.baseUrl}$avatarUrl'
          : '${ApiConstants.baseUrl}/$avatarUrl';
    }

    final originalSessions = req.originalSessions ?? [];
    final proposedSessions = req.sessions.isNotEmpty
        ? req.sessions
        : (req.timeIn != null || req.timeOut != null
            ? [
                {'time_in': req.timeIn ?? '', 'time_out': req.timeOut ?? ''}
              ]
            : <Map<String, dynamic>>[]);

    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: widget.isEmbedded
            ? BorderRadius.circular(16)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: widget.isEmbedded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Drag handle for bottom sheets
          if (!widget.isEmbedded)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Employee Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                            errorWidget: (context, url, error) => _buildInitials(req.userName),
                          )
                        : _buildInitials(req.userName),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              req.userName,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusBadge(req.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${req.typeLabel} • ${DateFormat('MMM dd, yyyy').format(req.requestDate)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Actions when Pending & Admin
                if (isAdmin && isPending) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isOverride = !_isOverride;
                        if (!_isOverride) {
                          _overrideSessions = List<Map<String, dynamic>>.from(proposedSessions);
                        }
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _isOverride ? const Color(0xFFF59E0B).withValues(alpha: 0.12) : null,
                      foregroundColor: _isOverride ? const Color(0xFFF59E0B) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      side: BorderSide(
                        color: _isOverride ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(
                      _isOverride ? Icons.edit_note_rounded : Icons.edit_rounded,
                      size: 14,
                      color: _isOverride ? const Color(0xFFF59E0B) : null,
                    ),
                    label: Text(
                      _isOverride ? 'Override Active' : 'Manual Override',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                if (widget.onClose != null)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Scrollable Content
          Expanded(
            flex: widget.isEmbedded ? 1 : 0,
            child: _isFetching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Manual Override Active Banner (when Pending and Override toggled)
                        if (isAdmin && isPending && _isOverride) ...[
                          _buildManualOverrideBanner(isDark, proposedSessions),
                          const SizedBox(height: 16),
                        ],

                        // 1. Full 24-Hour Visual Correction Timeline
                        VisualCorrectionTimeline(
                          originalSessions: originalSessions,
                          proposedSessions: _isOverride ? _overrideSessions : proposedSessions,
                          isDark: isDark,
                          editable: isAdmin && isPending && _isOverride,
                          onSessionsChange: (updated) {
                            setState(() {
                              _overrideSessions = updated;
                            });
                          },
                          onResetToOriginal: () {
                            setState(() {
                              _overrideSessions = List<Map<String, dynamic>>.from(proposedSessions);
                            });
                            context.showToast("Reset to employee's original requested punches", isSuccess: false);
                          },
                        ),

                        const SizedBox(height: 16),

                        // 2. Supporting Document / Proof Card (hooks into CorrectionDocumentModal)
                        CorrectionDocumentCard(
                          attachmentUrl: req.attachmentUrl,
                          isDark: isDark,
                        ),

                        const SizedBox(height: 16),

                        // 3. Information & Employee Stated Justification Grid
                        _buildRequestInfoAndReasonCard(req, isDark),

                        // 4. Reviewer Decision Banner (if already reviewed)
                        if (!isPending) ...[
                          const SizedBox(height: 16),
                          _buildReviewerDecisionCard(req, isDark),
                        ],

                        const SizedBox(height: 20),

                        // 5. Action Bar for Admin
                        if (isAdmin && isPending)
                          _buildAdminActionBar(req, isDark),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualOverrideBanner(bool isDark, List<Map<String, dynamic>> proposedSessions) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Manual Override Active',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Drag handles or edit below',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'You can modify punch handles directly on the timeline, then click Approve to apply.',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _overrideSessions = List<Map<String, dynamic>>.from(proposedSessions);
              });
              context.showToast("Reset to employee's original requested punches", isSuccess: false);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
              side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.restore_rounded, size: 12),
            label: Text('Reset', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Text(
      initial,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case RequestStatus.approved:
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        label = 'Approved';
        break;
      case RequestStatus.rejected:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        label = 'Rejected';
        break;
      case RequestStatus.pending:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildRequestInfoAndReasonCard(AttendanceCorrectionRequest req, bool isDark) {
    final cardBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REQUEST DETAILS & REASON',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  label: 'Category',
                  value: req.typeLabel,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  label: 'Method',
                  value: req.methodLabel,
                  isDark: isDark,
                ),
              ),
              if (req.submittedAt != null)
                Expanded(
                  child: _buildInfoItem(
                    label: 'Submitted',
                    value: DateFormat('MMM dd, hh:mm a').format(req.submittedAt!),
                    isDark: isDark,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Employee Stated Justification',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: const BorderSide(color: Color(0xFF6366F1), width: 3),
                top: BorderSide(color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                right: BorderSide(color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                bottom: BorderSide(color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Text(
              '"${req.reason.isNotEmpty ? req.reason : "No specific remarks provided."}"',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildReviewerDecisionCard(AttendanceCorrectionRequest req, bool isDark) {
    final isApproved = req.status == RequestStatus.approved;
    final color = isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                'Decision: ${req.status.name.toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              if (req.reviewedAt != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(req.reviewedAt!),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          if (req.reviewComments != null && req.reviewComments!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              req.reviewComments!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminActionBar(AttendanceCorrectionRequest req, bool isDark) {
    return Row(
      children: [
        // Reject button
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _openRejectDialog(req),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(
                'Reject',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Approve button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(
                _isOverride ? 'Approve with Overrides' : 'Approve Request',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
