import 'package:flutter/material.dart';
import '../../../../shared/widgets/sidebars/sidebar_tablet_landscape.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/navigation/navigation_controller.dart';

import 'dashboard_view.dart';
import '../../../employees/tablet/views/employees_view.dart';
import '../../../attendance/tablet/views/my_attendance_view.dart';
import '../../../live_attendance/tablet/views/live_attendance_view.dart';
import '../../../reports/tablet/views/reports_view.dart';
import '../../../leave/tablet/views/leave_view.dart';
import '../../../policy_engine/tablet/views/policy_engine_view.dart';
import '../../../profile/tablet/views/profile_view.dart';
import '../../../feedback/tablet/views/landscape.dart';
import '../../../daily_activity/daily_activity_screen.dart';
import '../../../geo_fencing/tablet/views/geo_fencing_view.dart';

class TabletLandscape extends StatelessWidget {
  const TabletLandscape({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC), // Solid background
      // decoration: BoxDecoration(...) removed for flat design
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            const SidebarTabletLandscape(),
            Expanded(
              child: Scaffold(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF0D1117) // Matches Sidebar
                    : Colors.transparent,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: ValueListenableBuilder<PageType>(
                    valueListenable: navigationNotifier,
                    builder: (context, currentPage, _) {
                      return CustomAppBar(
                        title: currentPage.title,
                        showDrawerButton: false, // Sidebar is visible
                      );
                    },
                  ),
                ),
                body: ValueListenableBuilder<PageType>(
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
                        return LeaveView();
                      case PageType.policyEngine:
                        return const PolicyEngineView();
                      case PageType.feedback:
                        return const FeedbackTabletLandscape();
                      case PageType.profile:
                        return const ProfileView();
                      case PageType.dailyActivity:
                        return const DailyActivityScreen();
                      case PageType.geoFencing:
                        return const GeoFencingView();
                      default:
                        return Center(child: Text('Page: ${currentPage.title}'));
                    }
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
