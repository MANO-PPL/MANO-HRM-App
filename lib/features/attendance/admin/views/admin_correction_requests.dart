
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/services/auth_service.dart';
import '../../models/correction_request.dart';
import '../../services/attendance_service.dart';
import '../../providers/attendance_provider.dart';
import '../widgets/correction_detail_dialog.dart';

/// Role-aware correction requests list.
/// - Admin / HR: see all org requests, can approve / reject.
/// - Employee: see only their own requests, read-only.
class AdminCorrectionRequests extends StatefulWidget {
  /// If provided, filters requests to this userId (for employee self-view).
  /// Admin view passes null to fetch all.
  final String? userId;
  final bool isPersonalView;

  const AdminCorrectionRequests({super.key, this.userId, this.isPersonalView = false});

  @override
  State<AdminCorrectionRequests> createState() => _AdminCorrectionRequestsState();
}

class _AdminCorrectionRequestsState extends State<AdminCorrectionRequests> {
  late AttendanceService _service;
  bool _isLoading = true;
  List<AttendanceCorrectionRequest> _requests = [];
  String _filterStatus = 'Pending'; // 'Pending' or 'History'
  bool _isAdmin = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);
    _userId = widget.userId ?? (widget.isPersonalView ? authService.user?.id : null);
    _isAdmin = (authService.user?.isAdmin ?? false) && !widget.isPersonalView;
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final status = _filterStatus.toLowerCase();
      final allRequests = await _service.getCorrectionRequests(
        status: status == 'pending' ? 'pending' : null,
        userId: _userId,
      );

      setState(() {
        var filtered = allRequests;
        if (widget.isPersonalView && _userId != null) {
          filtered = filtered.where((r) => r.userId == _userId).toList();
        }

        if (status == 'history') {
          _requests = filtered
              .where((r) => r.status != RequestStatus.pending)
              .toList();
        } else {
          _requests = filtered
              .where((r) => r.status == RequestStatus.pending)
              .toList();
        }
        _isLoading = false;

        // Reactive update to tab bar badge
        if (mounted) {
          final pendingCount = filtered.where((r) => r.status == RequestStatus.pending).length;
          Provider.of<AttendanceProvider>(context, listen: false).updatePendingCorrectionCount(pendingCount);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading corrections: $e')),
      );
    }
  }

  void _showDetail(AttendanceCorrectionRequest request) {
    CorrectionDetailDialog.show(
      context,
      request: request,
      onStatusChanged: _fetchRequests,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Title + Tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Row(
            children: [
              // Role-based title
              Expanded(
                child: Text(
                  _isAdmin ? 'All Correction Requests' : 'My Correction Requests',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              // Refresh button
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
                onPressed: _fetchRequests,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Filter Tabs
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              _buildTabButton('Pending', _filterStatus == 'Pending', isDark),
              const SizedBox(width: 12),
              _buildTabButton('History', _filterStatus == 'History', isDark),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _fetchRequests,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          return _buildRequestCard(_requests[index], isDark);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final isPending = _filterStatus == 'Pending';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_actions_outlined : Icons.history_outlined,
            size: 56,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isPending
                ? (_isAdmin ? 'No pending requests' : 'No pending requests from you')
                : 'No history found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPending && !_isAdmin
                ? 'Submit a correction request from the Mark Attendance tab.'
                : 'All requests will appear here.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isActive, bool isDark) {
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: () {
        if (_filterStatus != label) {
          setState(() => _filterStatus = label);
          _fetchRequests();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor
                : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(AttendanceCorrectionRequest req, bool isDark) {
    final isPending = req.status == RequestStatus.pending;

    return GestureDetector(
      onTap: () => _showDetail(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.07),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            // User Avatar
            _buildAvatar(req, isDark),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Always show employee name prominently as the main title
                  Text(
                    req.userName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${req.typeLabel} • ${DateFormat('MMM dd, yyyy').format(req.requestDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.reason.length > 60
                        ? '${req.reason.substring(0, 57)}...'
                        : req.reason,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Status + Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusBadge(req.status),
                const SizedBox(height: 6),
                if (req.submittedAt != null)
                  Text(
                    DateFormat('hh:mm a').format(req.submittedAt!),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ),
                // Quick action buttons for admin pending
                if (_isAdmin && isPending) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildMiniActionChip(
                        icon: Icons.check,
                        color: const Color(0xFF059669),
                        onTap: () => _showDetail(req),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionChip({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildAvatar(AttendanceCorrectionRequest req, bool isDark) {
    final primary = isDark ? const Color(0xFF5B60F6) : const Color(0xFF4F46E5);
    return CircleAvatar(
      radius: 22,
      backgroundColor: primary.withOpacity(0.12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: req.userAvatar != null && req.userAvatar!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: req.userAvatar!,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                placeholder: (_, __) => _avatarFallback(req.userName, isDark),
                errorWidget: (_, __, ___) => _avatarFallback(req.userName, isDark),
              )
            : _avatarFallback(req.userName, isDark),
      ),
    );
  }

  Widget _avatarFallback(String name, bool isDark) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case RequestStatus.approved:
        color = const Color(0xFF059669);
        label = 'Approved';
        icon = Icons.check_circle_outline;
        break;
      case RequestStatus.rejected:
        color = const Color(0xFFDC2626);
        label = 'Rejected';
        icon = Icons.cancel_outlined;
        break;
      default:
        color = const Color(0xFFD97706);
        label = 'Pending';
        icon = Icons.schedule_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
