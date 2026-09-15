import 'package:flutter/material.dart';
import 'package:flutter_application/shared/widgets/sidebars/sidebar_mobile.dart';
import 'package:flutter_application/shared/widgets/custom_app_bar.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/dashboard/views/dashboard_mobile_portrait_view.dart';
import 'package:flutter_application/features/employees/views/employees_mobile_portrait_view.dart';
import 'package:flutter_application/features/attendance/views/attendance_mobile_portrait_view.dart';
import 'package:flutter_application/features/live_attendance/views/live_attendance_mobile_portrait_view.dart';
import 'package:flutter_application/features/reports/reports_page.dart';
import 'package:flutter_application/features/profile/views/profile_mobile_portrait_view.dart';
import 'package:flutter_application/features/policies/views/policies_mobile_portrait_view.dart';
import 'package:flutter_application/features/leave/leave_page.dart';
import 'package:flutter_application/features/daily_activity/daily_activity_page.dart';
import 'package:flutter_application/shared/widgets/chatbot_fab.dart';
import 'package:flutter_application/features/feedback/views/feedback_mobile_portrait_view.dart';
import 'package:flutter_application/features/collaboration/collaboration_page.dart';
import 'package:flutter_application/features/labour/views/labour_mobile_portrait_view.dart';
import 'package:flutter_application/features/payroll/views/payroll_mobile_portrait_view.dart';

class MobilePortrait extends StatelessWidget {
  const MobilePortrait({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: SidebarMobile(
          onLinkTap: () {
            Navigator.pop(context);
          },
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: Column(
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
                  builder: (context, currentPage, child) {
                    return _buildContent(context, currentPage, isDark);
                  },
                ),
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

  Widget _buildContent(BuildContext context, PageType page, bool isDark) {
    switch (page) {
      case PageType.dashboard:
        return const MobileDashboardContent();
      case PageType.employees:
        return const EmployeesMobileView();
      case PageType.myAttendance:
        return const MobileMyAttendanceContent();
      case PageType.liveAttendance:
        return const MobileLiveAttendanceContent();
      case PageType.reports:
        return const ReportsView();
      case PageType.leavesAndHolidays:
        return const LeavePage();
      case PageType.payroll:
        return const PayrollScreenMobile();
      case PageType.profile:
        return const MobileProfileContent();
      case PageType.policies:
      case PageType.policyEngine:
      case PageType.geoFencing:
        return const PoliciesMobileView();
      case PageType.dailyActivity:
        return const DailyActivityScreen();
      case PageType.feedback:
        return const FeedbackMobileView();
      case PageType.collaboration:
        return const CollaborationScreen();
      case PageType.labourManagement:
        return const LabourMobileContent();
    }
  }
}

// commit-marker: 2026-02-22T14:20:00+05:30

// [mod:2026-02-22T17:00:00+05:30]

// [upd:2026-04-30T11:30:00+05:30]

// [rev:2026-08-24T15:30:00+05:30]
