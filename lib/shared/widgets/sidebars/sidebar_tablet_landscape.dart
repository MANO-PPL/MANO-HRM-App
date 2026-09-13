import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class SidebarTabletLandscape extends StatelessWidget {
  final VoidCallback? onLinkTap;

  const SidebarTabletLandscape({super.key, this.onLinkTap});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: 260,
      height: double.infinity,
      blur: 0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D1117)
          : const Color(0xFFFFFFFF),
      borderRadius: 0,
      border: Border(
        right: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF30363D)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
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
              // Fixed Sidebar Header (Aligned with AppBar)
              Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/mano.png',
                      height: 36,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF5B60F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.change_history, color: Color(0xFF5B60F6), size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'MANO',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5B60F6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Menu Items
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigateTo(PageType.feedback);
                        if (onLinkTap != null) onLinkTap!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: currentPage == PageType.feedback
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFF4338CA).withValues(alpha: 0.1))
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF161B22)
                                  : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF30363D)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined,
                              size: 18,
                              color: currentPage == PageType.feedback
                                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF4338CA))
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Bugs & Feedback",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
                    const SizedBox(height: 6),
                    Text(
                      "v1.0.0",
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400],
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1.5),
      child: Material(
        color: isActive
            ? (isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            navigateTo(page);
            if (onLinkTap != null) onLinkTap!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(
                  page.icon,
                  size: 17,
                  color: isActive
                      ? (isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA))
                      : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    page.getTitle(isEmployee),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? (isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA))
                          : (isDark ? const Color(0xFFC9D1D9) : const Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// [upd:2026-04-29T14:00:00+05:30]

// [upd:2026-05-08T17:00:00+05:30]

// [rev:2026-08-24T18:00:00+05:30]
