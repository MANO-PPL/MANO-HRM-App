import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../navigation/navigation_controller.dart';
import '../glass_container.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SidebarTabletLandscape extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const SidebarTabletLandscape({super.key, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    // Fixed Sidebar for Landscape
    return GlassContainer(
      width: 280,
      height: double.infinity,
      blur: 0, 
      color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF0D1117) // Standardized Dark Mode Color
          : const Color(0xFFFFFFFF),
      borderRadius: 0, 
      child: _SidebarContent(onLinkTap: onLinkTap),
    );
  }
}

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
              // Fixed Sidebar Header (Aligned with AppBar)
              Container(
                height: 55,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF30363D) 
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                     // Logo Icon (Using similar style to provided image if possible, or keeping existing)
                     Image.asset(
                       'assets/mano.png', 
                       height: 40,
                       errorBuilder: (context, error, stackTrace) => Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(color: const Color(0xFF5B60F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                         child: const Icon(Icons.change_history, color: Color(0xFF5B60F6), size: 24),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Text(
                       'MANO',
                       style: GoogleFonts.poppins(
                         fontSize: 22,
                         fontWeight: FontWeight.bold,
                         color: const Color(0xFF5B60F6), // Match Brand Color
                         letterSpacing: 1.0,
                       ),
                     ),
                  ],
                ),
              ),
              
              // Scrollable Menu Items
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isActive 
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF4338CA).withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
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
