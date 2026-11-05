import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/services/dashboard_provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/dashboard/widgets/employee_dashboard_widgets.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_dialog.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class EmployeeDashboardView extends StatefulWidget {
  const EmployeeDashboardView({super.key});

  @override
  State<EmployeeDashboardView> createState() => _EmployeeDashboardViewState();
}

class _EmployeeDashboardViewState extends State<EmployeeDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData(forceRefresh: true);
      final attendance = Provider.of<AttendanceProvider>(context, listen: false);
      attendance.fetchShiftPolicy();
      attendance.checkMissedPunch();
      attendance.fetchRecords(DateTime.now(), forceRefresh: true).then((_) {
        if (mounted) {
          context.checkAndShowShiftStartBanner();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final attendanceProvider = context.watch<AttendanceProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final missedDate = attendanceProvider.missedPunchDate;
    final canSubmitCorrection = attendanceProvider.canSubmitCorrection;
    final stats = dashboardProvider.stats;

    return LoadingScreen(
      isLoading: dashboardProvider.isLoading,
      message: "Loading dashboard...",
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 580;
          final useFourColStats = constraints.maxWidth >= 720;
          final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 16.0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Web Welcome Banner (Edge-to-edge flush from header)
                EmployeeWelcomeBanner(
                  userName: user?.name ?? 'Employee',
                  department: user?.department,
                  designation: user?.designation,
                  shift: attendanceProvider.shiftPolicy,
                  records: attendanceProvider.records,
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Missed Punch Banner (if applicable)
                      if (missedDate != null && canSubmitCorrection) ...[
                        MissedPunchBanner(
                          missedDate: missedDate,
                          onFixNow: () {
                            CorrectionRequestDialog.show(
                              context,
                              date: missedDate,
                              attendanceId: null,
                              type: CorrectionType.missedPunch,
                              onSuccess: () {
                                attendanceProvider.clearMissedPunch();
                                attendanceProvider.checkMissedPunch();
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],

                      // 3. Quick Stats Grid (4 Dynamic Cards matching web: Present, Late, Absent, Avg Hours)
                      if (useFourColStats)
                        Row(
                          children: [
                            Expanded(
                              child: EmployeeStatCard(
                                label: 'Present Days',
                                value: stats.presentToday.toString(),
                                icon: Icons.check_circle_outline,
                                iconColor: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: EmployeeStatCard(
                                label: 'Late Arrivals',
                                value: stats.lateCheckins.toString(),
                                icon: Icons.access_time_rounded,
                                iconColor: const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: EmployeeStatCard(
                                label: 'Absent Days',
                                value: stats.absentToday.toString(),
                                icon: Icons.cancel_outlined,
                                iconColor: const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: EmployeeStatCard(
                                label: 'Avg Work Hours',
                                value: '${stats.avgHours.toStringAsFixed(1)}h',
                                icon: Icons.trending_up_rounded,
                                iconColor: const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        )
                      else
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.6,
                          children: [
                            EmployeeStatCard(
                              label: 'Present Days',
                              value: stats.presentToday.toString(),
                              icon: Icons.check_circle_outline,
                              iconColor: const Color(0xFF10B981),
                            ),
                            EmployeeStatCard(
                              label: 'Late Arrivals',
                              value: stats.lateCheckins.toString(),
                              icon: Icons.access_time_rounded,
                              iconColor: const Color(0xFFF59E0B),
                            ),
                            EmployeeStatCard(
                              label: 'Absent Days',
                              value: stats.absentToday.toString(),
                              icon: Icons.cancel_outlined,
                              iconColor: const Color(0xFFEF4444),
                            ),
                            EmployeeStatCard(
                              label: 'Avg Work Hours',
                              value: '${stats.avgHours.toStringAsFixed(1)}h',
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xFF6366F1),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),

                      // 4. Two-Column Split Section: Recent Activity & Upcoming Holidays
                      if (isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            EmployeeRecentActivityCard(
                              records: attendanceProvider.records,
                            ),
                            const SizedBox(height: 10),
                            EmployeeUpcomingHolidaysCard(
                              holidays: dashboardProvider.upcomingHolidays,
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EmployeeRecentActivityCard(
                                records: attendanceProvider.records,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: EmployeeUpcomingHolidaysCard(
                                holidays: dashboardProvider.upcomingHolidays,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
