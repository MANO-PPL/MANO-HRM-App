import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/daily_activity/views/daily_activity_tablet_portrait_view.dart';
import 'package:flutter_application/features/daily_activity/views/daily_activity_mobile_portrait_view.dart';
import 'package:flutter_application/features/daily_activity/widgets/employees_dar_admin_view.dart';

class DailyActivityScreen extends StatelessWidget {
  const DailyActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isAdmin = auth.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myDarView = const ResponsiveLayout(
      mobile: MobileDailyActivityView(),
      tabletPortrait: TabletDailyActivityView(isLandscape: false),
      tabletLandscape: TabletDailyActivityView(isLandscape: true),
    );

    if (!isAdmin) {
      return myDarView;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    final isMobilePortrait = screenWidth < 600 && orientation == Orientation.portrait;
    final isTabletPortrait = screenWidth >= 600 && orientation == Orientation.portrait;

    final double horizontalPadding;
    if (screenWidth < 600) {
      horizontalPadding = isMobilePortrait ? 10 : 14;
    } else if (isTabletPortrait) {
      horizontalPadding = 16;
    } else {
      horizontalPadding = 24;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Pill Styled Tab Bar (Matching Attendance, Leave, Payroll, Feedback)
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                6,
                horizontalPadding,
                isMobilePortrait ? 6 : 8,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobilePortrait ? 3 : 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  labelPadding: EdgeInsets.symmetric(horizontal: isMobilePortrait ? 2 : 6),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    borderRadius: BorderRadius.circular(isMobilePortrait ? 7 : 8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white : const Color(0xFF4F46E5),
                  unselectedLabelColor: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: isMobilePortrait ? 11.5 : (isTabletPortrait ? 13 : 13.5),
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: isMobilePortrait ? 11.5 : (isTabletPortrait ? 13 : 13.5),
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(
                      height: isMobilePortrait ? 34 : (isTabletPortrait ? 38 : 40),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: isMobilePortrait ? 15 : 17,
                            ),
                            SizedBox(width: isMobilePortrait ? 6 : 8),
                            const Text("My DAR"),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: isMobilePortrait ? 34 : (isTabletPortrait ? 38 : 40),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: isMobilePortrait ? 15 : 17,
                            ),
                            SizedBox(width: isMobilePortrait ? 6 : 8),
                            const Text("Employees' DAR"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded Views Content
            Expanded(
              child: TabBarView(
                children: [
                  myDarView,
                  const EmployeesDarAdminView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [upd:2026-04-15T11:30:00+05:30]

// [upd:2026-05-13T11:30:00+05:30]
