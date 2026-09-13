import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/services/notification_service.dart';
import 'package:flutter_application/shared/models/notification_model.dart';
import 'package:flutter_application/shared/utils/notification_helper.dart';
import 'package:intl/intl.dart';

class NotificationList extends StatefulWidget {
  final bool isMobilePage;
  const NotificationList({super.key, this.isMobilePage = false});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  String _activeTab = 'Unread';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NotificationService>(context, listen: false).fetchNotifications();
      }
    });
  }

  Widget _buildSwitcher(BuildContext context, NotificationService service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);
    final activeBg = isDark ? const Color(0xFF2D3139) : Colors.white;
    final activeColor = isDark ? Colors.white : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Unread', 'Read'].map((tab) {
          final isSelected = _activeTab == tab;
          final hasBadge = tab == 'Unread' && service.unreadCount > 0;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 4.5),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))
                        : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: isSelected && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab == 'Unread' ? Icons.mail_outline_rounded : Icons.mark_email_read_outlined,
                      size: 13,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                    if (hasBadge) ...[
                      const SizedBox(width: 5),
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${service.unreadCount}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, service, child) {
        final notifications = service.filteredNotifications;
        final isLoading = service.isLoading;

        final filteredNotifications = notifications.where((n) {
          if (_activeTab == 'Unread') {
            return !n.isRead;
          } else {
            return n.isRead;
          }
        }).toList();

        final showMarkAllRead = _activeTab == 'Unread' && service.unreadCount > 0;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMobilePage) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (showMarkAllRead)
                      TextButton(
                        onPressed: () => service.markAllAsRead(),
                        child: Text('Mark all read', style: GoogleFonts.poppins(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
            if (widget.isMobilePage) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildSwitcher(context, service),
                    ),
                    if (showMarkAllRead) ...[
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => service.markAllAsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Mark all read', style: GoogleFonts.poppins(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildSwitcher(context, service),
              ),
            ],
            const Divider(height: 1),
          ],
        );

        final content = Column(
          children: [
            header,
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : filteredNotifications.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _activeTab == 'Unread' 
                                  ? Icons.mark_email_read_outlined 
                                  : Icons.notifications_off_outlined, 
                              size: 48, 
                              color: Colors.grey[400]
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeTab == 'Unread' 
                                  ? 'All caught up! No unread notifications' 
                                  : 'No read notifications', 
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filteredNotifications.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return _buildNotificationItem(context, filteredNotifications[index], service);
                        },
                      ),
            ),
          ],
        );

        if (widget.isMobilePage) {
           return content; // Return plain content for Scaffold body
        }

        return GlassContainer(
          width: 350,
          height: 400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: content,
        );
      },
    );
  }

  Widget _buildNotificationItem(BuildContext context, NotificationModel note, NotificationService service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = note.isRead ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05));
    
    return InkWell(
      onTap: () => service.markAsRead(note.id),
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _getTypeColor(note.type).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getTypeIcon(note.type), size: 15, color: _getTypeColor(note.type)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: note.isRead ? FontWeight.normal : FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    note.message,
                    style: GoogleFonts.poppins(fontSize: 11.5, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                     _formatTime(note.createdAt),
                     style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!note.isRead)
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM dd').format(time);
  }

  Color _getTypeColor(String type) {
    final cat = NotificationHelper.categoryForType(type);
    switch (cat) {
      case NotificationCategory.checkinReminder:
      case NotificationCategory.checkoutReminder:
        return Colors.teal;
      case NotificationCategory.missedPunch:
        return Colors.deepOrange;
      case NotificationCategory.leaveStatus:
        return Colors.purple;
      case NotificationCategory.correctionStatus:
        return Colors.indigo;
      case NotificationCategory.darReminder:
        return Colors.blue;
      case NotificationCategory.announcement:
        return Colors.amber.shade700;
      case NotificationCategory.leaveRequest:
        return Colors.green;
      case NotificationCategory.correction:
        return Colors.orange;
      case NotificationCategory.pendingApprovals:
        return Colors.red;
      case NotificationCategory.teamAlert:
        return Colors.cyan.shade700;
      case NotificationCategory.systemAlert:
        return Colors.blueGrey;
      case NotificationCategory.general:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    final cat = NotificationHelper.categoryForType(type);
    switch (cat) {
      case NotificationCategory.checkinReminder:
        return Icons.login_rounded;
      case NotificationCategory.checkoutReminder:
        return Icons.logout_rounded;
      case NotificationCategory.missedPunch:
        return Icons.warning_amber_rounded;
      case NotificationCategory.leaveStatus:
        return Icons.beach_access_rounded;
      case NotificationCategory.correctionStatus:
        return Icons.edit_calendar_rounded;
      case NotificationCategory.darReminder:
        return Icons.assignment_rounded;
      case NotificationCategory.announcement:
        return Icons.campaign_rounded;
      case NotificationCategory.leaveRequest:
        return Icons.inbox_rounded;
      case NotificationCategory.correction:
        return Icons.rate_review_rounded;
      case NotificationCategory.pendingApprovals:
        return Icons.pending_actions_rounded;
      case NotificationCategory.teamAlert:
        return Icons.groups_rounded;
      case NotificationCategory.systemAlert:
        return Icons.admin_panel_settings_rounded;
      case NotificationCategory.general:
        return Icons.info_outline;
    }
  }
}

// [upd:2026-04-29T09:00:00+05:30]

// [upd:2026-05-08T14:00:00+05:30]
