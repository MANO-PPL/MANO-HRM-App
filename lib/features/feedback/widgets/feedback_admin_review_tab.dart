import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/services/feedback_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class FeedbackAdminReviewTab extends StatefulWidget {
  final FeedbackService feedbackService;
  final bool isDark;

  const FeedbackAdminReviewTab({
    super.key,
    required this.feedbackService,
    required this.isDark,
  });

  @override
  State<FeedbackAdminReviewTab> createState() => _FeedbackAdminReviewTabState();
}

class _FeedbackAdminReviewTabState extends State<FeedbackAdminReviewTab> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL'; // ALL, OPEN, IN_PROGRESS, RESOLVED
  String _selectedType = 'ALL';   // ALL, BUG, FEEDBACK

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.feedbackService.getAllFeedback(
        status: _selectedStatus == 'ALL' ? '' : _selectedStatus,
        type: _selectedType == 'ALL' ? '' : _selectedType,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _tickets = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showToast('Failed to load feedback: $e', isError: true);
      }
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      await widget.feedbackService.updateFeedbackStatus(id, newStatus);
      if (mounted) {
        context.showToast('Ticket #$id updated to $newStatus', isSuccess: true);
        _fetchTickets();
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Failed to update status: $e', isError: true);
      }
    }
  }

  List<dynamic> get _filteredTickets {
    return _tickets.where((ticket) {
      final t = ticket is Map ? ticket : {};
      final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
      final type = (t['type'] ?? 'BUG').toString().toUpperCase();

      if (_selectedStatus != 'ALL' && status != _selectedStatus) return false;
      if (_selectedType != 'ALL' && type != _selectedType) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final cardBg = widget.isDark ? const Color(0xFF161B22) : Colors.white;

    final filtered = _filteredTickets;

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _filterChip('Status: All', _selectedStatus == 'ALL', () {
                setState(() => _selectedStatus = 'ALL');
                _fetchTickets();
              }),
              const SizedBox(width: 6),
              _filterChip('Open', _selectedStatus == 'OPEN', () {
                setState(() => _selectedStatus = 'OPEN');
                _fetchTickets();
              }),
              const SizedBox(width: 6),
              _filterChip('In Progress', _selectedStatus == 'IN_PROGRESS', () {
                setState(() => _selectedStatus = 'IN_PROGRESS');
                _fetchTickets();
              }),
              const SizedBox(width: 6),
              _filterChip('Resolved', _selectedStatus == 'RESOLVED', () {
                setState(() => _selectedStatus = 'RESOLVED');
                _fetchTickets();
              }),
              const Spacer(),
              IconButton(
                onPressed: _fetchTickets,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 44, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No tickets found',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTickets,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final t = filtered[i] is Map ? filtered[i] : {};
                          final id = t['id'] ?? t['feedback_id'] ?? 0;
                          final title = t['title'] ?? 'No Title';
                          final desc = t['description'] ?? '';
                          final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
                          final type = (t['type'] ?? 'BUG').toString().toUpperCase();
                          final userName = t['user_name'] ?? t['userName'] ?? 'User';
                          final userEmail = t['user_email'] ?? t['email'];
                          final createdAt = t['created_at']?.toString().split('T').first ?? '';

                          Color statusColor;
                          Color statusBg;
                          switch (status) {
                            case 'RESOLVED':
                              statusColor = const Color(0xFF10B981);
                              statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
                              break;
                            case 'IN_PROGRESS':
                              statusColor = const Color(0xFF3B82F6);
                              statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
                              break;
                            case 'OPEN':
                            default:
                              statusColor = const Color(0xFFF59E0B);
                              statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
                              break;
                          }

                          final isBug = type == 'BUG';

                          return Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isBug
                                            ? Colors.red.withValues(alpha: 0.12)
                                            : Colors.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isBug ? Icons.bug_report : Icons.feedback,
                                        size: 16,
                                        color: isBug ? Colors.red : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title.toString(),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            '$userName ${userEmail != null ? "($userEmail)" : ""}  •  $createdAt',
                                            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Dropdown / Action
                                    PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (id is int && id > 0) {
                                          _updateStatus(id, val);
                                        } else if (int.tryParse(id.toString()) != null) {
                                          _updateStatus(int.parse(id.toString()), val);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'OPEN', child: Text('Open')),
                                        const PopupMenuItem(value: 'IN_PROGRESS', child: Text('In Progress')),
                                        const PopupMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              status,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (desc.toString().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    desc.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: widget.isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onTap) {
    final activeBg = const Color(0xFF4F46E5);
    final inactiveBg = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
