import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class SidebarMobile extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const SidebarMobile({super.key, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    // Mobile Drawer Standard Width
    return Drawer(
      width: 240,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        width: double.infinity,
        height: double.infinity,
        blur: 20,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0D1117)
            : const Color(0xFFFFFFFF),
        borderRadius: 0,
        child: _SidebarContent(onLinkTap: onLinkTap),
      ),
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
        final user = context.read<AuthService>().user;
        final isEmployee = user != null && user.isEmployee;

        // Clean list of nav items matching Attendance-Web
        final navPages = [
          PageType.dashboard,
          if (!isEmployee) PageType.employees,
          if (!isEmployee) PageType.labourManagement,
          PageType.myAttendance,
          if (!isEmployee) PageType.liveAttendance,
          PageType.reports,
          if (!isEmployee) PageType.payroll,
          PageType.dailyActivity,
          if (!isEmployee) PageType.policies,
          PageType.leavesAndHolidays,
        ];

        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Sidebar Header
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerLeft,
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/mano.png',
                              height: 32,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.change_history, color: Theme.of(context).primaryColor, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'MANO',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Menu Items
                      ...navPages.map((page) => _buildMenuItem(
                            context,
                            page,
                            currentPage == page,
                            isEmployee: isEmployee,
                          )),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Item: Bugs & Feedback (Custom Button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigateTo(PageType.feedback);
                        if (onLinkTap != null) {
                          onLinkTap!();
                        } else {
                          Navigator.pop(context);
                        }
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
                                fontSize: 13,
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
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, PageType page, bool isActive, {bool isEmployee = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: isActive
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF4338CA).withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          horizontalTitleGap: 8,
          minLeadingWidth: 20,
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Icon(
            page.icon,
            size: 20,
            color: isActive
                ? (isDark ? Colors.white : const Color(0xFF4338CA))
                : (isDark ? Colors.grey : Colors.black54),
          ),
          title: Text(
            page.getTitle(isEmployee),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? (isDark ? Colors.white : const Color(0xFF4338CA))
                  : (isDark ? Colors.grey[400] : Colors.black87),
            ),
          ),
          onTap: () {
            navigateTo(page);
            if (onLinkTap != null) {
              onLinkTap!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}

// [upd:2026-04-29T14:00:00+05:30]

// [upd:2026-05-08T17:00:00+05:30]
