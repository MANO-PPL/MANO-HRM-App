import 'package:flutter/material.dart';
import '../../../../shared/widgets/sidebars/sidebar_tablet_portrait.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import 'dashboard_view.dart';
import '../../../employees/tablet/views/employees_view.dart';
import '../../../attendance/tablet/views/my_attendance_view.dart';
import '../../../live_attendance/tablet/views/live_attendance_view.dart';
import '../../../reports/tablet/views/reports_view.dart';
import '../../../leave/tablet/views/leave_view.dart'; // UPDATED
import '../../../policy_engine/tablet/views/policy_engine_view.dart';
import '../../../profile/tablet/views/profile_view.dart';
import '../../../feedback/tablet/views/portrait.dart';
import '../../../daily_activity/daily_activity_screen.dart'; // ADDED
import '../../../geo_fencing/tablet/views/geo_fencing_view.dart';

class TabletPortrait extends StatelessWidget {
  const TabletPortrait({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC), // Dynamic background
      // Gradients removed for stricter flat design
      // decoration: BoxDecoration(...) removed
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        backgroundColor: Colors.transparent, // Transparent to show gradient
        drawer: SidebarTabletPortrait(
          onLinkTap: () {
            Navigator.pop(context); // Close drawer on selection
          },
        ),
        body: Stack(
          children: [
            // Background Elements could go here
            
            Column(
              children: [
                // Sticky Header
                ValueListenableBuilder<PageType>(
                  valueListenable: navigationNotifier,
                  builder: (context, currentPage, _) {
                    return CustomAppBar(
                      title: currentPage.title,
                      showDrawerButton: true,
                    );
                  }
                ),

                // Scrollable Content Region
                Expanded(
                  child: ValueListenableBuilder<PageType>(
                    valueListenable: navigationNotifier,
                    builder: (context, currentPage, _) {
                      // Dynamic Body Content
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
                           return LeaveView(); // UPDATED (removed const)
                        case PageType.policyEngine:
                           return const PolicyEngineView();
                        case PageType.dailyActivity:
                           return const DailyActivityScreen(); // ADDED
                        case PageType.geoFencing:
                           return const GeoFencingView();
                        case PageType.feedback:
                           return const FeedbackTabletPortrait();
                        case PageType.profile:
                           return const ProfileView();
                      }
                    }
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


