import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_container.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
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
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
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
                      size: 14,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                    if (hasBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${service.unreadCount}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
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
        final notifications = service.notifications;
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildSwitcher(context, service),
                    ),
                    if (showMarkAllRead) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => service.markAllAsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Mark all read', style: GoogleFonts.poppins(fontSize: 12)),
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
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getTypeColor(note.type).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getTypeIcon(note.type), size: 16, color: _getTypeColor(note.type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: note.isRead ? FontWeight.normal : FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.message,
                    style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                     _formatTime(note.createdAt),
                     style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (!note.isRead)
              Container(
                width: 8,
                height: 8,
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
    switch (type) {
      case 'warning': return Colors.orange;
      case 'error': return Colors.red;
      case 'success': return Colors.green;
      default: return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'error': return Icons.error_outline;
      case 'success': return Icons.check_circle_outline;
      default: return Icons.info_outline;
    }
  }
}
