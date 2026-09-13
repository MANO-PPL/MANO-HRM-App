import 'package:flutter/material.dart';
import 'package:flutter_application/features/dashboard/widgets/dashboard_tablet_view.dart';
import 'package:flutter_application/features/employees/views/employees_tablet_portrait_view.dart';
import 'package:flutter_application/features/attendance/attendance_page.dart';
import 'package:flutter_application/features/live_attendance/views/live_attendance_tablet_portrait_view.dart';
import 'package:flutter_application/features/leave/leave_page.dart';
import 'package:flutter_application/features/reports/reports_page.dart';
import 'package:flutter_application/features/policies/policies_page.dart';
import 'package:flutter_application/features/feedback/feedback_page.dart';
import 'package:flutter_application/features/daily_activity/daily_activity_page.dart';
import 'package:flutter_application/features/profile/views/profile_tablet_portrait_view.dart';
import 'package:flutter_application/features/collaboration/collaboration_page.dart';
import 'package:flutter_application/features/payroll/payroll_page.dart';
import 'package:flutter_application/features/labour/views/labour_mobile_portrait_view.dart';
import 'package:flutter_application/features/labour/views/labour_tablet_portrait_view.dart';
import 'package:flutter_application/features/labour/views/labour_tablet_landscape_view.dart';
import 'package:flutter_application/shared/layout/responsive_layout.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/widgets/sidebars/sidebar_tablet_landscape.dart';
import 'package:flutter_application/shared/widgets/custom_app_bar.dart';

import 'package:flutter_application/shared/widgets/chatbot_fab.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            const SidebarTabletLandscape(),
            Expanded(
              child: ValueListenableBuilder<PageType>(
                valueListenable: navigationNotifier,
                builder: (context, currentPage, _) {
                  return Scaffold(
                    backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.transparent,
                    appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(kToolbarHeight),
                      child: CustomAppBar(
                        showDrawerButton: false,
                        title: currentPage.title,
                      ),
                    ),
                    body: SafeArea(
                      top: false,
                      bottom: true,
                      child: _buildPage(currentPage),
                    ),
                    floatingActionButton: ChatbotFab(currentPageType: currentPage),
                    floatingActionButtonLocation: ChatbotFabLocation(currentPage),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(PageType page) {
    switch (page) {
      case PageType.dashboard:
        return const DashboardView();
      case PageType.employees:
        return const EmployeesView();
      case PageType.myAttendance:
        return const AttendancePage();
      case PageType.liveAttendance:
        return const LiveAttendanceView();
      case PageType.leavesAndHolidays:
        return const LeaveView();
      case PageType.payroll:
        return const PayrollScreen();
      case PageType.reports:
        return const ReportsView();
      case PageType.labourManagement:
        return const ResponsiveLayout(
          mobile: LabourMobilePortraitView(),
          tabletPortrait: LabourTabletPortraitView(),
          tabletLandscape: LabourTabletLandscapeView(),
          desktop: LabourTabletLandscapeView(),
        );
      case PageType.policies:
      case PageType.policyEngine:
      case PageType.geoFencing:
        return const PoliciesView();
      case PageType.dailyActivity:
        return const DailyActivityScreen();
      case PageType.feedback:
        return const FeedbackView();
      case PageType.collaboration:
        return const CollaborationScreen();
      case PageType.profile:
        return const ProfileView();
    }
  }
}

// [upd:2026-04-27T14:00:00+05:30]

// [upd:2026-05-08T11:30:00+05:30]

// [upd:2026-05-13T14:00:00+05:30]

// [rev:2026-08-24T18:00:00+05:30]
