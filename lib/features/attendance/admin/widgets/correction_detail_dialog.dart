
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/constants/api_constants.dart';
import '../../models/correction_request.dart';
import '../../services/attendance_service.dart';
import '../../widgets/correction_ui_components.dart';
import '../../../../shared/widgets/toast_helper.dart';

class CorrectionDetailDialog extends StatefulWidget {
  final AttendanceCorrectionRequest request;
  final VoidCallback onStatusChanged;
  final bool isBottomSheet;

  const CorrectionDetailDialog({
    super.key, 
    required this.request,
    required this.onStatusChanged,
    this.isBottomSheet = false,
  });

  /// Always shows as a bottom sheet sliding from the bottom of the screen.
  /// On tablet, constrained to maxWidth: 560 centred.
  static Future<void> show(
    BuildContext context, {
    required AttendanceCorrectionRequest request,
    required VoidCallback onStatusChanged,
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width < 600 
            ? double.infinity 
            : 560,
      ),
      builder: (context) => CorrectionDetailDialog(
        request: request,
        onStatusChanged: onStatusChanged,
        isBottomSheet: true,
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
  final TextEditingController _commentController = TextEditingController();
  
  // Override State
  bool _isOverride = false;
  CorrectionMethod? _overrideMethod;
  TextEditingController _overrideInController = TextEditingController();
  TextEditingController _overrideOutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = AttendanceService(authService.dio);
    
    // Pre-fill overrides with requested times from initial data
    _overrideMethod = widget.request.method;
    _overrideInController.text = widget.request.requestedTimeIn ?? '';
    _overrideOutController.text = widget.request.requestedTimeOut ?? '';

    _fetchRequestDetails();
  }

  Future<void> _fetchRequestDetails() async {
    try {
      final detail = await _service.getCorrectionRequestDetail(widget.request.id);
      if (mounted) {
        setState(() {
          _fullRequest = detail;
          _isFetching = false;
          // Refresh override controllers if they were empty or to match full data
          if (_overrideInController.text.isEmpty) {
             _overrideInController.text = detail.requestedTimeIn ?? '';
          }
          if (_overrideOutController.text.isEmpty) {
             _overrideOutController.text = detail.requestedTimeOut ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching correction detail: $e");
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _updateStatus(RequestStatus status) async {
    if (status == RequestStatus.rejected && _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment is required for rejection')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      List<Map<String, String>>? overrideSessions;

      if (_isOverride && _overrideMethod != null) {
        final inTime = _overrideInController.text.contains(':') && _overrideInController.text.split(':').length == 2 
            ? '${_overrideInController.text}:00' 
            : _overrideInController.text;
        final outTime = _overrideOutController.text.contains(':') && _overrideOutController.text.split(':').length == 2 
            ? '${_overrideOutController.text}:00' 
            : _overrideOutController.text;

        // Both addSession and reset/fix use sessions array in the backend
        overrideSessions = [{'time_in': inTime, 'time_out': outTime}];
      }

      await _service.processCorrectionRequest(
        widget.request.id,
        status: status.toString().split('.').last.toLowerCase(),
        reviewComments: _commentController.text.isNotEmpty ? _commentController.text : null,
        sessions: overrideSessions,
      );
      
      if (!mounted) return;
      Navigator.pop(context);
      widget.onStatusChanged();
      
      if (!mounted) return;
      if (status == RequestStatus.approved) {
        context.showToast("The attendance correction has been successfully approved.", isSuccess: true);
      } else {
        context.showToast("The correction request has been rejected.", isSuccess: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickOverrideTime(bool isTimeIn) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF4F46E5),
            colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (isTimeIn) _overrideInController.text = formatted;
        else _overrideOutController.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = _fullRequest ?? widget.request;
    String? avatarUrl = req.userAvatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
      avatarUrl = avatarUrl.startsWith('/') ? '${ApiConstants.baseUrl}$avatarUrl' : '${ApiConstants.baseUrl}/$avatarUrl';
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwnRequest = req.userId == authService.user?.id;
    final isAdmin = (authService.user?.isAdmin ?? false) && !isOwnRequest;

    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;

    // Bottom sheet container that sizes to its content (max 92% of screen height)
    final sheetContent = Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF30363D) : Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle ──
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // HEADER SECTION
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${req.typeLabel} Request',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: isDark ? const Color(0xFF5B60F6) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: avatarUrl != null && avatarUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: avatarUrl,
                                                    fit: BoxFit.cover,
                                                    width: 24,
                                                    height: 24,
                                                    placeholder: (context, url) => Center(
                                                      child: Text(
                                                        req.userName.isNotEmpty ? req.userName[0] : '?',
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : Theme.of(context).primaryColor, 
                                                          fontWeight: FontWeight.bold, 
                                                          fontSize: 8
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Center(
                                                      child: Text(
                                                        req.userName.isNotEmpty ? req.userName[0] : '?',
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : Theme.of(context).primaryColor, 
                                                          fontWeight: FontWeight.bold, 
                                                          fontSize: 8
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    req.userName.isNotEmpty ? req.userName[0] : '?',
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white : Theme.of(context).primaryColor, 
                                                      fontWeight: FontWeight.bold, 
                                                      fontSize: 8
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'By ${req.userName} (${req.designation ?? (req.desgId == 1 ? "Manager" : "Employee")})',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (req.status == RequestStatus.pending && isAdmin)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildHeaderAction(
                                    icon: Icons.cancel_outlined,
                                    label: 'Reject',
                                    color: Colors.red,
                                    onPressed: _isLoading ? null : () => _updateStatus(RequestStatus.rejected),
                                    isDark: isDark,
                                    compact: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildHeaderAction(
                                    icon: Icons.check_circle_outline,
                                    label: 'Approve',
                                    color: const Color(0xFF059669),
                                    onPressed: _isLoading ? null : () => _updateStatus(RequestStatus.approved),
                                    isDark: isDark,
                                    isPrimary: true,
                                    compact: true,
                                  ),
                                ),
                              ],
                            ),
                   const SizedBox(height: 16),
                   if (req.status == RequestStatus.pending && isAdmin)
                     Row(
                       children: [
                         SizedBox(
                           height: 24,
                           width: 24,
                           child: Checkbox(
                             value: _isOverride,
                             onChanged: (val) => setState(() => _isOverride = val ?? false),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                           ),
                         ),
                         const SizedBox(width: 8),
                         Text(
                           'Override Request Details',
                           style: GoogleFonts.poppins(
                             fontSize: 14,
                             fontWeight: FontWeight.w600,
                             color: isDark ? Colors.white : const Color(0xFF1F2937),
                           ),
                         ),
                       ],
                     ),
                 ],
               ),
             ),
             
             Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
             ConstrainedBox(
               constraints: BoxConstraints(
                 maxHeight: MediaQuery.of(context).size.height * 0.65,
               ),
               child: _isFetching 
                 ? const Center(child: CircularProgressIndicator())
                 : SingleChildScrollView(
                 padding: const EdgeInsets.all(24),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // MAIN GRID
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;
                          final body = [
                            // LEFT COLUMN: CORRECTION DETAILS
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('CORRECTION DETAILS', isDark),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CorrectionDetailCard(
                                        label: 'Request Type',
                                        value: req.typeLabel.toUpperCase(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CorrectionDetailCard(
                                        label: 'Method',
                                        value: req.methodLabel.replaceAll('_', ' ').toUpperCase(),
                                        backgroundColor: isDark ? const Color(0xFF4F46E5).withOpacity(0.1) : const Color(0xFFEEF2FF),
                                        textColor: const Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Requested Sessions Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Requested Sessions',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (req.sessions.isEmpty && req.timeIn == null && req.timeOut == null)
                                        Text('No sessions requested', style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white24 : Colors.black26))
                                      else ...[
                                        if (req.sessions.isNotEmpty)
                                          ...req.sessions.map((s) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Text(
                                              '• ${s['time_in']} - ${s['time_out']}', 
                                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                          )),
                                        if (req.timeIn != null)
                                           Text('In: ${req.timeIn}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                        if (req.timeOut != null)
                                           Text('Out: ${req.timeOut}', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                      ],
                                    ],
                                  ),
                                ),
                                
                                if (_isOverride) ...[
                                   const SizedBox(height: 24),
                                   _buildSectionTitle('ADMIN OVERRIDE', isDark),
                                   const SizedBox(height: 12),
                                   CorrectionSegmentedControl<CorrectionMethod>(
                                     value: (_overrideMethod == null || _overrideMethod == CorrectionMethod.fix) 
                                         ? CorrectionMethod.addSession 
                                         : _overrideMethod!,
                                     items: {
                                       CorrectionMethod.reset: 'Reset Day',
                                       CorrectionMethod.addSession: 'Manual Correction',
                                     },
                                     onChanged: (val) => setState(() => _overrideMethod = val),
                                   ),
                                   const SizedBox(height: 12),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: CorrectionInputField(
                                           value: _overrideInController.text.isEmpty ? '--:--' : _overrideInController.text,
                                           suffixIcon: Icons.access_time,
                                           onTap: () => _pickOverrideTime(true),
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: CorrectionInputField(
                                           value: _overrideOutController.text.isEmpty ? '--:--' : _overrideOutController.text,
                                           suffixIcon: Icons.access_time,
                                           onTap: () => _pickOverrideTime(false),
                                         ),
                                       ),
                                     ],
                                   ),
                                ],
                              ],
                            ),

                            // RIGHT COLUMN: JUSTIFICATION
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 if (isMobile) const SizedBox(height: 24),
                                 _buildSectionTitle('JUSTIFICATION & COMMENTS', isDark),
                                 const SizedBox(height: 12),
                                 // Reason Card
                                 Container(
                                   width: double.infinity,
                                   padding: const EdgeInsets.all(16),
                                   decoration: BoxDecoration(
                                     color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF9FAFB),
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                   ),
                                   child: Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Icon(Icons.chat_bubble_outline, size: 18, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: Text(
                                           '"${req.reason}"',
                                           style: GoogleFonts.poppins(
                                             fontSize: 14,
                                             fontStyle: FontStyle.italic,
                                             color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                           ),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 12),
                                 if (req.status == RequestStatus.pending && isAdmin)
                                   TextField(
                                     controller: _commentController,
                                     maxLines: 4,
                                     style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                     decoration: InputDecoration(
                                       hintText: 'Add a review comment...',
                                       hintStyle: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white24 : const Color(0xFF9CA3AF)),
                                       filled: true,
                                       fillColor: isDark ? Colors.transparent : Colors.white,
                                       border: OutlineInputBorder(
                                         borderRadius: BorderRadius.circular(12),
                                         borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                       ),
                                       enabledBorder: OutlineInputBorder(
                                         borderRadius: BorderRadius.circular(12),
                                         borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                                       ),
                                     ),
                                   )
                                 else if (req.reviewComments != null) ...[
                                    _buildSectionTitle('REVIEW COMMENTS', isDark),
                                    const SizedBox(height: 8),
                                    Text(
                                      req.reviewComments!,
                                      style: GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                                    ),
                                 ],
                              ],
                            ),
                          ];

                          if (isMobile) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: body,
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: body.map((e) => Expanded(child: Padding(
                              padding: EdgeInsets.only(right: e == body.last ? 0 : 32),
                              child: e,
                            ))).toList(),
                          );
                        },
                      ),
                     
                     const SizedBox(height: 32),
                     Divider(color: isDark ? Colors.white10 : Colors.black12),
                     const SizedBox(height: 24),
                     
                     // AUDIT TRAIL
                     _buildSectionTitle('AUDIT TRAIL', isDark, icon: Icons.timeline),
                     const SizedBox(height: 16),
                     CorrectionAuditItem(
                       title: 'Submitted',
                       subtitle: '${DateFormat('M/d/yyyy, h:mm:ss a').format(req.submittedAt ?? req.requestDate)} • by ${req.userName}',
                       isLast: req.status == RequestStatus.pending,
                     ),
                     if (req.status != RequestStatus.pending)
                        CorrectionAuditItem(
                          title: req.status == RequestStatus.approved ? 'Approved' : 'Rejected',
                          subtitle: '${req.reviewedAt != null ? DateFormat('M/d/yyyy, h:mm:ss a').format(req.reviewedAt!) : "Recently"} • by ${req.reviewedBy ?? "Admin"}',
                          isLast: true,
                        ),
                   ],
                 ),
               ),
             ),
          ],
        ),
      ),
    );

    return sheetContent;
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    required bool isDark,
    bool isPrimary = false,
    bool compact = false,
  }) {
    if (compact) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: isPrimary ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? null : Border.all(color: color.withOpacity(0.2)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: isPrimary ? Colors.white : color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
