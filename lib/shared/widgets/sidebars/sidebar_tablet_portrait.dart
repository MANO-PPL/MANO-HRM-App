import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/navigation_controller.dart';
import '../glass_container.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SidebarTabletPortrait extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const SidebarTabletPortrait({super.key, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    // Tablet Portrait Drawer (Usually behaves like a drawer but wider/different style)
    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        width: double.infinity,
        height: double.infinity,
        blur: 0, 
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF0D1117) // Standardized Dark Mode Color
            : const Color(0xFFFFFFFF),
        borderRadius: 0, 
        child: _SidebarContent(onLinkTap: onLinkTap),
      ),
    );
  }
}

// Reusing content logic but separating widget for file isolation as requested
class _SidebarContent extends StatelessWidget {
  final VoidCallback? onLinkTap;
  const _SidebarContent({this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PageType>(
      valueListenable: navigationNotifier,
      builder: (context, currentPage, _) {
        return SafeArea(
          child: Column(
            children: [
               // Sidebar Header
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF30363D) 
                          : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/mano.png',
                      height: 48,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.change_history, color: Theme.of(context).primaryColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MANO',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      // Menu Items
                      ...PageType.values.where((p) {
                        final user = context.read<AuthService>().user;
                        if (user != null && user.isEmployee) {
                            final allowed = [
                              PageType.dashboard,
                              PageType.myAttendance,
                              PageType.leavesAndHolidays,
                              PageType.feedback,
                              PageType.profile,
                            ];
                            if (!allowed.contains(p)) return false;
                        }
                         if (p == PageType.profile) return false;
                         if (p == PageType.feedback) return false; // Hide feedback from list
                        return true;
                      }).map((page) => _buildMenuItem(
                        context, 
                        page,
                        currentPage == page,
                      )),
                    ],
                  ),
                ),
              ),
  
               // Fixed Bottom: Bugs & Feedback
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                         navigateTo(PageType.feedback);
                         if (onLinkTap != null) onLinkTap!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: currentPage == PageType.feedback
                              ? (Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white.withValues(alpha: 0.1) 
                                  : const Color(0xFF4338CA).withValues(alpha: 0.1))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined, 
                              size: 20,
                              color: currentPage == PageType.feedback
                                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4338CA))
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Bugs & Feedback",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: currentPage == PageType.feedback ? FontWeight.w600 : FontWeight.w500,
                                color: currentPage == PageType.feedback
                                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4338CA))
                                    : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMenuItem(BuildContext context, PageType page, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive 
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF4338CA).withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        horizontalTitleGap: 8,
        minLeadingWidth: 20,
        leading: Icon(
          page.icon,
          color: isActive 
              ? (isDark ? Colors.white : const Color(0xFF4338CA))
              : (isDark ? Colors.grey : Colors.black54),
        ),
        title: Text(
          page.title,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive 
                ? (isDark ? Colors.white : const Color(0xFF4338CA))
                : (isDark ? Colors.grey[400] : Colors.black87),
          ),
        ),
        onTap: () {
          navigateTo(page);
          if (onLinkTap != null) onLinkTap!();
        },
      ),
    );
  }
}
