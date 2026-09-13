import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/providers/theme_simple.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/notifications/views/notifications_mobile_portrait_view.dart'; // Import Mobile View
import 'package:flutter_application/shared/services/notification_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/collaboration/core/chat_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showDrawerButton;
  final String title;

  const CustomAppBar({
    super.key, 
    this.showDrawerButton = true,
    this.title = 'Dashboard',
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isMobilePortrait = isMobile && MediaQuery.of(context).orientation == Orientation.portrait;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1117) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: isMobilePortrait ? 50 : 56,
            padding: EdgeInsets.fromLTRB(
              isMobile ? 2 : (MediaQuery.of(context).size.width < 900 ? 8 : 24),
              0,
              isMobile ? 4 : 24,
              0,
            ),
            child: Row(
              children: [
                if (showDrawerButton)
                  IconButton(
                    padding: isMobilePortrait ? const EdgeInsets.all(2) : (isMobile ? const EdgeInsets.all(4) : const EdgeInsets.all(8)),
                    constraints: isMobile ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                    icon: Icon(Icons.menu, size: isMobilePortrait ? 22 : 24, color: Theme.of(context).iconTheme.color),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final user = context.watch<AuthService>().user;
                      final isEmployee = user != null && user.isEmployee;
                      final displayTitle = (isEmployee && title == 'Reports') ? 'My Reports' : title;

                      return Text(
                        displayTitle,
                        style: GoogleFonts.poppins(
                          fontSize: isMobilePortrait ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                ),
                
                // Theme Switcher Button
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark; 
                    return IconButton(
                      padding: isMobile ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                      constraints: isMobile ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      onPressed: () {
                        toggleTheme();
                      },
                    );
                  },
                ),

                // Chat & Collaboration Button
                Consumer<ChatService>(
                  builder: (context, chatService, _) {
                    return ValueListenableBuilder<PageType>(
                      valueListenable: navigationNotifier,
                      builder: (context, currentPage, _) {
                        final isActive = currentPage == PageType.collaboration;
                        return Stack(
                          children: [
                            IconButton(
                              padding: isMobile ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                              constraints: isMobile ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                              icon: Icon(
                                isActive ? Icons.forum : Icons.forum_outlined,
                                color: isActive ? const Color(0xFF5B60F6) : null,
                              ),
                              tooltip: 'Chat & Collaborate',
                              onPressed: () {
                                navigationNotifier.value = PageType.collaboration;
                              },
                            ),
                            if (chatService.totalUnreadCount > 0)
                              Positioned(
                                right: isMobile ? 2 : 8,
                                top: isMobile ? 2 : 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${chatService.totalUnreadCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),

                // Notification Icon with Badge
                Consumer<NotificationService>(
                  builder: (context, notificationService, _) {
                    return Stack(
                      children: [
                        IconButton(
                          padding: isMobile ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
                          constraints: isMobile ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
                          icon: const Icon(Icons.notifications_outlined),
                          tooltip: 'Notifications',
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const NotificationsView()),
                            );
                          },
                        ),
                        if (notificationService.unreadCount > 0)
                          Positioned(
                            right: isMobile ? 2 : 8,
                            top: isMobile ? 2 : 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${notificationService.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                if (isMobilePortrait) ...[
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final user = Provider.of<AuthService>(context).user;
                      final name = user?.name ?? 'Guest';
                      final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

                      return InkWell(
                        onTap: () {
                          navigationNotifier.value = PageType.profile;
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Container(
                            decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(color: const Color(0xFF5B60F6).withValues(alpha: 0.2)),
                            ),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                              backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                                  ? NetworkImage(user.profileImage!)
                                  : null,
                              child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                                  ? Text(initials, style: GoogleFonts.poppins(color: const Color(0xFF5B60F6), fontWeight: FontWeight.bold, fontSize: 11))
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                ],

                if (MediaQuery.of(context).size.width > 600) ...[
                  const SizedBox(width: 16),
                  // User Profile
                  Builder(
                    builder: (context) {
                      final user = Provider.of<AuthService>(context).user;
                      final name = user?.name ?? 'Guest';
                      final role = user?.role.toUpperCase() ?? '';
                      final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

                      return Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<String>(
                          offset: const Offset(0, 60),
                          color: Colors.transparent,
                          elevation: 0,
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          enableFeedback: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          tooltip: 'Profile Options',
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              enabled: false, 
                              padding: EdgeInsets.zero,
                              child: GlassContainer(
                                width: 220,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDropdownItem(context, icon: Icons.person_outline, text: 'View Profile', onTap: () {
                                       navigationNotifier.value = PageType.profile;
                                       Navigator.pop(context);
                                    }),
                                    Divider(height: 1, thickness: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[200]),
                                    _buildDropdownItem(context, icon: Icons.logout, text: 'Logout', onTap: () async {
                                      Navigator.pop(context); // Close dropdown
                                      
                                      final auth = Provider.of<AuthService>(context, listen: false);
                                      await auth.logout();
                                      
                                      if (context.mounted) {
                                        context.showToast('Logged out successfully', isSuccess: true);
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (_) => const AuthWrapper()),
                                          (route) => false,
                                        );
                                      }
                                    }, isDestructive: true),
                                  ],
                                ),
                              ),
                            )
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  Text(
                                    role,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   border: Border.all(color: const Color(0xFF5B60F6).withValues(alpha: 0.2)),
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                                  backgroundImage: (user?.profileImage != null && user!.profileImage!.isNotEmpty)
                                      ? NetworkImage(user.profileImage!)
                                      : null,
                                  child: (user?.profileImage == null || user!.profileImage!.isEmpty)
                                      ? Text(initials, style: GoogleFonts.poppins(color: const Color(0xFF5B60F6), fontWeight: FontWeight.bold, fontSize: 13))
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownItem(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap, bool isDestructive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

// commit-marker: 2026-02-27T18:00:00+05:30

// [mod:2026-02-27T17:30:00+05:30]

// [upd:2026-04-29T11:30:00+05:30]
