import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/features/attendance/core/attendance_service.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/attendance/widgets/correction_detail_dialog.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_dialog.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_dialog_mobile.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/models/user_model.dart';

/// Role-aware correction requests view with full responsiveness across:
/// - Mobile Portrait (< 600px): Clean card list with bottom sheet detail viewer.
/// - Tablet Portrait (600px - 950px): Wide list with modal detail dialog.
/// - Tablet Landscape (>= 950px): High-productivity Dual-Pane Master-Detail layout.
class AdminCorrectionRequests extends StatefulWidget {
  final String? userId;
  final bool isPersonalView;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AdminCorrectionRequests({
    super.key,
    this.userId,
    this.isPersonalView = false,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<AdminCorrectionRequests> createState() => _AdminCorrectionRequestsState();
}

class _AdminCorrectionRequestsState extends State<AdminCorrectionRequests> {
  late AttendanceService _service;
  bool _isLoading = true;
  List<AttendanceCorrectionRequest> _allRequests = [];
  List<AttendanceCorrectionRequest> _requests = [];
  String _filterStatus = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _searchQuery = '';
  AttendanceCorrectionRequest? _selectedRequest;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);
    _fetchRequests();
  }

  @override
  void didUpdateWidget(AdminCorrectionRequests oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPersonalView != widget.isPersonalView || oldWidget.userId != widget.userId) {
      _fetchRequests();
    }
  }

  bool _matchesCurrentUser(AttendanceCorrectionRequest r, User? user) {
    if (user == null) return false;
    final rUid = r.userId.trim().toLowerCase();
    final rEmpId = (r.employeeId ?? '').trim().toLowerCase();
    final rUname = r.userName.trim().toLowerCase();

    final myId = user.id.trim().toLowerCase();
    final myEmpId = user.employeeId.trim().toLowerCase();
    final myUsername = user.username.trim().toLowerCase();
    final myName = user.name.trim().toLowerCase();

    // 1. Direct ID / Employee ID / Username matching
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

    // 2. Full Name matching fallback
    if (rUname.isNotEmpty && rUname != 'unknown' && myName.isNotEmpty && rUname == myName) {
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.user;
      final userIdent = currentUser?.employeeId.isNotEmpty == true ? currentUser?.employeeId : currentUser?.id;

      // In personal view, pass user identifier to backend if available
      final queryUserId = widget.isPersonalView ? userIdent : widget.userId;

      final allRequests = await _service.getCorrectionRequests(
        status: null,
        userId: queryUserId,
      );

      setState(() {
        var filtered = allRequests;
        if (widget.isPersonalView) {
          // Strictly filter to only requests belonging to the logged-in user
          filtered = filtered.where((r) => _matchesCurrentUser(r, currentUser)).toList();
        }

        _allRequests = filtered;
        _applyFilter();
        _isLoading = false;

        // Keep selection if still in filtered list, else pick first
        if (_selectedRequest != null) {
          final match = _requests.where((r) => r.id == _selectedRequest!.id).toList();
          _selectedRequest = match.isNotEmpty ? match.first : (_requests.isNotEmpty ? _requests.first : null);
        } else if (_requests.isNotEmpty) {
          _selectedRequest = _requests.first;
        }

        // Reactive update to Live Attendance tab bar badge (only for admin all-requests view)
        if (mounted && !widget.isPersonalView) {
          final pendingCount = filtered.where((r) => r.status == RequestStatus.pending).length;
          Provider.of<AttendanceProvider>(context, listen: false).updatePendingCorrectionCount(pendingCount);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showToast('Error loading corrections: $e', isError: true);
    }
  }

  void _applyFilter() {
    List<AttendanceCorrectionRequest> list = _allRequests;

    // Status filter
    if (_filterStatus == 'Pending') {
      list = list.where((r) => r.status == RequestStatus.pending).toList();
    } else if (_filterStatus == 'Approved') {
      list = list.where((r) => r.status == RequestStatus.approved).toList();
    } else if (_filterStatus == 'Rejected') {
      list = list.where((r) => r.status == RequestStatus.rejected).toList();
    }

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((r) {
        final nameMatch = r.userName.toLowerCase().contains(q);
        final reasonMatch = r.reason.toLowerCase().contains(q);
        final typeMatch = r.typeLabel.toLowerCase().contains(q);
        final idMatch = r.id.toLowerCase().contains(q);
        return nameMatch || reasonMatch || typeMatch || idMatch;
      }).toList();
    }

    _requests = list;
    if (_selectedRequest != null && !_requests.any((r) => r.id == _selectedRequest!.id)) {
      _selectedRequest = _requests.isNotEmpty ? _requests.first : null;
    }
  }

  void _showDetail(AttendanceCorrectionRequest request) {
    setState(() => _selectedRequest = request);
    CorrectionDetailDialog.show(
      context,
      request: request,
      onStatusChanged: _fetchRequests,
    );
  }

  Future<void> _openCorrectionRequestDialog() async {
    if (MediaQuery.of(context).size.width < 600) {
      await CorrectionRequestDialogMobile.show(context, onSuccess: _fetchRequests);
    } else {
      await CorrectionRequestDialog.show(context, onSuccess: _fetchRequests);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCount = _allRequests.length;
    final pendingCount = _allRequests.where((r) => r.status == RequestStatus.pending).length;
    final approvedCount = _allRequests.where((r) => r.status == RequestStatus.approved).length;
    final rejectedCount = _allRequests.where((r) => r.status == RequestStatus.rejected).length;

    return LoadingScreen(
      isLoading: _isLoading && _allRequests.isEmpty,
      message: "Loading correction requests...",
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth >= 950 && !widget.shrinkWrap;

          if (isLandscape) {
            // High-productivity Dual-Pane Master-Detail View
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Master Column: Filter, Search & List
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 10),
                      _buildSearchBar(isDark),
                      const SizedBox(height: 10),
                      _buildFilterTabs(allCount, pendingCount, approvedCount, rejectedCount, isDark),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _requests.isEmpty
                            ? _buildEmptyState(isDark)
                            : RefreshIndicator(
                                onRefresh: _fetchRequests,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: _requests.length,
                                  itemBuilder: (context, index) {
                                    final req = _requests[index];
                                    final isSelected = _selectedRequest?.id == req.id;
                                    return _buildRequestCard(req, isDark, isSelected: isSelected, onSelect: () {
                                      setState(() => _selectedRequest = req);
                                    });
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),

                // Right Detail Column: Embedded Correction Detail
                Expanded(
                  child: _selectedRequest != null
                      ? KeyedSubtree(
                          key: ValueKey(_selectedRequest!.id),
                          child: CorrectionDetailDialog(
                            request: _selectedRequest!,
                            onStatusChanged: _fetchRequests,
                            isEmbedded: true,
                          ),
                        )
                      : _buildNoSelectionState(isDark),
                ),
              ],
            );
          }

          // Single Column Layout for Tablet Portrait and Mobile
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 10),
              _buildSearchBar(isDark),
              const SizedBox(height: 10),
              _buildFilterTabs(allCount, pendingCount, approvedCount, rejectedCount, isDark),
              const SizedBox(height: 10),
              widget.shrinkWrap
                  ? (_requests.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: widget.physics,
                          padding: EdgeInsets.zero,
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(
                              _requests[index],
                              isDark,
                              onSelect: () => _showDetail(_requests[index]),
                            );
                          },
                        ))
                  : Expanded(
                      child: _requests.isEmpty
                          ? _buildEmptyState(isDark)
                          : RefreshIndicator(
                              onRefresh: _fetchRequests,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _requests.length,
                                itemBuilder: (context, index) {
                                  return _buildRequestCard(
                                    _requests[index],
                                    isDark,
                                    onSelect: () => _showDetail(_requests[index]),
                                  );
                                },
                              ),
                            ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.isPersonalView ? 'My Correction Requests' : 'Correction Requests',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
        // Request Correction Action Button
        InkWell(
          onTap: _openCorrectionRequestDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 15, color: Color(0xFF6366F1)),
                const SizedBox(width: 4),
                Text(
                  'Request Correction',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            size: 20,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
          onPressed: _fetchRequests,
          tooltip: 'Refresh',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 16,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilter();
                });
              },
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                hintText: 'Search employee, reason, or #ID...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _applyFilter();
                });
              },
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int all, int pending, int approved, int rejected, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabButton('All', all, isDark),
          const SizedBox(width: 6),
          _buildTabButton('Pending', pending, isDark),
          const SizedBox(width: 6),
          _buildTabButton('Approved', approved, isDark),
          const SizedBox(width: 6),
          _buildTabButton('Rejected', rejected, isDark),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int count, bool isDark) {
    final isActive = _filterStatus == label;
    final activeColor = const Color(0xFF6366F1);

    return GestureDetector(
      onTap: () {
        if (_filterStatus != label) {
          setState(() {
            _filterStatus = label;
            _applyFilter();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 11,
                color: isActive
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.robotoMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    AttendanceCorrectionRequest req,
    bool isDark, {
    bool isSelected = false,
    required VoidCallback onSelect,
  }) {
    String? avatarUrl = req.userAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      avatarUrl = avatarUrl.startsWith('/')
          ? '${ApiConstants.baseUrl}$avatarUrl'
          : '${ApiConstants.baseUrl}/$avatarUrl';
    }

    // Calculate total proposed hours
    double totalHours = 0;
    for (final s in req.sessions) {
      totalHours += _calculateDurationHours(s['time_in'], s['time_out']);
    }

    final cardBg = isSelected
        ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.35) : const Color(0xFFEEF2FF))
        : (isDark ? const Color(0xFF161B22) : Colors.white);

    final borderColor = isSelected
        ? const Color(0xFF6366F1)
        : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + ID + Status
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            width: 32,
                            height: 32,
                            errorWidget: (context, url, error) => _buildInitials(req.userName),
                          )
                        : _buildInitials(req.userName),
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
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${req.id} • ${req.typeLabel}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(req.status),
              ],
            ),

            const SizedBox(height: 8),

            // Middle Row: Date & Duration Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, MMM dd, yyyy').format(req.requestDate),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                if (totalHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${totalHours.toStringAsFixed(1)} hrs',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Stated Reason Snippet
            Text(
              req.reason.isNotEmpty ? req.reason : 'No explanation provided.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.white38 : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Proof attachment chip
            if (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 12, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      req.attachmentUrl!.split('?').first.split('/').last,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6366F1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildInitials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Text(
      initial,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              _filterStatus == 'All'
                  ? 'No correction requests found'
                  : 'No $_filterStatus requests found',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _openCorrectionRequestDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(
                      'Request Correction',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelectionState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 56,
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Request to Review',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Click any correction request on the left pane to view punch comparisons, supporting proof, and take approval actions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateDurationHours(String? inTime, String? outTime) {
    if (inTime == null || outTime == null || inTime.isEmpty || outTime.isEmpty) return 0;
    try {
      final inM = _parseMinutes(inTime);
      final outM = _parseMinutes(outTime);
      if (inM != null && outM != null && outM > inM) {
        return (outM - inM) / 60.0;
      }
    } catch (_) {}
    return 0;
  }

  int? _parseMinutes(String raw) {
    try {
      final clean = raw.trim();
      final timePart = clean.contains(' ')
          ? clean.split(' ')[1]
          : (clean.contains('T') ? clean.split('T')[1] : clean);
      final parts = timePart.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h * 60 + m;
      }
    } catch (_) {}
    return null;
  }
}
