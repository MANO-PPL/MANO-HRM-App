import 'package:flutter/material.dart';
import 'package:flutter_application/shared/widgets/sidebars/sidebar_tablet_portrait.dart';
import 'package:flutter_application/shared/widgets/custom_app_bar.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/dashboard/widgets/dashboard_tablet_view.dart';
import 'package:flutter_application/features/employees/views/employees_tablet_portrait_view.dart';
import 'package:flutter_application/features/attendance/views/attendance_tablet_portrait_view.dart';
import 'package:flutter_application/features/live_attendance/views/live_attendance_tablet_portrait_view.dart';
import 'package:flutter_application/features/reports/reports_page.dart';
import 'package:flutter_application/features/leave/leave_page.dart';
import 'package:flutter_application/features/policies/views/policies_tablet_portrait_view.dart';
import 'package:flutter_application/features/profile/views/profile_tablet_portrait_view.dart';
import 'package:flutter_application/features/feedback/views/feedback_tablet_portrait_view.dart';
import 'package:flutter_application/features/daily_activity/daily_activity_page.dart';
import 'package:flutter_application/features/collaboration/collaboration_page.dart';
import 'package:flutter_application/features/labour/views/labour_tablet_portrait_view.dart';
import 'package:flutter_application/features/payroll/views/payroll_tablet_portrait_view.dart';
import 'package:flutter_application/shared/widgets/chatbot_fab.dart';

class TabletPortrait extends StatelessWidget {
  const TabletPortrait({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: SidebarTabletPortrait(
          onLinkTap: () {
            Navigator.pop(context);
          },
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Stack(
            children: [
              Column(
                children: [
                  ValueListenableBuilder<PageType>(
                    valueListenable: navigationNotifier,
                    builder: (context, currentPage, _) {
                      return CustomAppBar(
                        title: currentPage.title,
                        showDrawerButton: true,
                      );
                    },
                  ),
                  Expanded(
                    child: ValueListenableBuilder<PageType>(
                      valueListenable: navigationNotifier,
                      builder: (context, currentPage, _) {
                        switch (currentPage) {
                          case PageType.dashboard:
                            return const DashboardView();
                          case PageType.employees:
                            return const EmployeesView();
                          case PageType.myAttendance:
                            return const MyAttendanceView();
                          case PageType.liveAttendance:
                            return const LiveAttendanceView();
                          case PageType.reports:
                            return const ReportsView();
                          case PageType.leavesAndHolidays:
                            return const LeavePage();
                          case PageType.payroll:
                            return const PayrollScreenTablet();
                          case PageType.policies:
                          case PageType.policyEngine:
                          case PageType.geoFencing:
                            return const PoliciesTabletPortraitView();
                          case PageType.dailyActivity:
                            return const DailyActivityScreen();
                          case PageType.feedback:
                            return const FeedbackTabletPortrait();
                          case PageType.profile:
                            return const ProfileView();
                          case PageType.collaboration:
                            return const CollaborationScreen();
                          case PageType.labourManagement:
                            return const LabourTabletContent();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: ValueListenableBuilder<PageType>(
          valueListenable: navigationNotifier,
          builder: (context, currentPage, _) {
            return ChatbotFab(currentPageType: currentPage);
          },
        ),
        floatingActionButtonLocation: DynamicChatbotFabLocation(navigationNotifier),
      ),
    );
  }
}

// [mod:2026-02-22T17:00:00+05:30]

// [rev:2026-08-24T15:30:00+05:30]
