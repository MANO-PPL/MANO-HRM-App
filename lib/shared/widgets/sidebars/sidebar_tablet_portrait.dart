import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class SidebarTabletPortrait extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const SidebarTabletPortrait({super.key, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 280,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        width: double.infinity,
        height: double.infinity,
        blur: 0,
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
              // Sidebar Header
              Container(
                height: 55,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
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
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.change_history, color: Theme.of(context).primaryColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MANO',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
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

              // Fixed Bottom: Bugs & Feedback
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            if (onLinkTap != null) onLinkTap!();
          },
        ),
      ),
    );
  }
}

// commit-marker: 2026-02-27T18:00:00+05:30

// [mod:2026-02-27T17:30:00+05:30]

// [upd:2026-04-29T14:00:00+05:30]

// [upd:2026-05-08T17:00:00+05:30]

// [rev:2026-08-24T18:00:00+05:30]
