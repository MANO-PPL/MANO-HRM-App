import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts
import 'package:provider/provider.dart';
import '../../../../shared/services/dashboard_provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/dashboard_model.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import '../../tablet/widgets/action_card.dart';
import '../../tablet/widgets/activity_feed.dart';
import '../../tablet/widgets/stat_card.dart';
import '../../tablet/widgets/trends_chart.dart';
import '../../widgets/employee_dashboard_widgets.dart';
import '../../../policy_engine/tablet/views/policy_engine_view.dart';
import '../../../../shared/widgets/loading_screen.dart';
import 'package:flutter_application/features/attendance/providers/attendance_provider.dart';
import '../../../../features/leave/providers/leave_provider.dart';
import '../../../../shared/widgets/toast_helper.dart';

import '../../../employees/mobile/views/employees_mobile_view.dart';
import '../../../attendance/mobile/views/my_attendance_view.dart';
import '../../../live_attendance/mobile/views/live_attendance_view.dart';
import '../../../reports/mobile/views/reports_view.dart';
import '../../../geo_fencing/mobile/views/geo_fencing_view.dart';
import '../../../leave/tablet/views/leave_view.dart'; // Reusing tablet view
import '../../../daily_activity/daily_activity_screen.dart'; // ADDED
import '../../../feedback/mobile/views/feedback_mobile_view.dart'; // Reusing tablet view
import '../../../collaboration/collaboration_screen.dart'; // ADDED
import 'package:flutter_application/shared/widgets/chatbot_fab.dart';

class MobileLandscape extends StatelessWidget {
  const MobileLandscape({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9), // Solid background
      // decoration: BoxDecoration(...) removed for flat design
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: AppSidebar(
          onLinkTap: () => Navigator.pop(context),
        ),
        body: ValueListenableBuilder<PageType>(
          valueListenable: navigationNotifier,
          builder: (context, currentPage, _) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: CustomAppBar(
                title: currentPage.title,
                showDrawerButton: true,
              ),
              body: _buildContent(context, currentPage),
              floatingActionButton: ChatbotFab(currentPageType: currentPage),
              floatingActionButtonLocation: ChatbotFabLocation(currentPage),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PageType page) {
    switch (page) {
      case PageType.dashboard:
        return const MobileDashboardLandscapeDispatcher();
      
      case PageType.employees:
         return const EmployeesMobileView();
      
      case PageType.myAttendance:
         return const MobileMyAttendanceContent();
      
      case PageType.liveAttendance:
          return const MobileLiveAttendanceContent();

      case PageType.reports:
          return const MobileReportsContent();

      case PageType.leavesAndHolidays: // UPDATED
          return LeaveView();

      case PageType.geoFencing:
        return const MobileGeoFencingContent();

      case PageType.dailyActivity:
        return const DailyActivityScreen(); // ADDED
           
      case PageType.feedback:
           return const FeedbackMobileView();

      case PageType.policyEngine:
         return const PolicyEngineView();
      case PageType.profile:
         return Center(child: Text('${page.title} (Landscape)'));
      case PageType.collaboration:
         return const CollaborationScreen(); // ADDED
    }
  }
}

class MobileDashboardLandscapeDispatcher extends StatelessWidget {
  const MobileDashboardLandscapeDispatcher({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    
    if (user == null) {
       return const LoadingScreen(message: "Authenticating...");
    }

    if (user.isEmployee) {
      return const MobileEmployeeDashboardLandscape();
    }
    if (user.isHr) {
      return const MobileHrDashboardLandscape();
    }
    return const MobileAdminDashboardLandscape();
  }
}

class MobileEmployeeDashboardLandscape extends StatefulWidget {
  const MobileEmployeeDashboardLandscape({super.key});

  @override
  State<MobileEmployeeDashboardLandscape> createState() => _MobileEmployeeDashboardLandscapeState();
}

class _MobileEmployeeDashboardLandscapeState extends State<MobileEmployeeDashboardLandscape> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData(forceRefresh: true);
      Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true)
          .then((_) {
            if (mounted) {
              context.checkAndShowShiftStartBanner();
            }
          });
      Provider.of<LeaveProvider>(context, listen: false).fetchMyLeaves(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final leaveProvider = context.watch<LeaveProvider>();
    final myLeaves = leaveProvider.myLeaves;

    // Calculate real leave balance from approved requests
    int approvedDays = 0;
    for (var leave in myLeaves) {
      if (leave.status.toLowerCase() == 'approved') {
        final diff = leave.endDate.difference(leave.startDate).inDays + 1;
        approvedDays += diff;
      }
    }
    final leaveBalance = (12 - approvedDays).clamp(0, 12);
    
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Loading dashboard...",
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Edge-to-Edge Gradient Header
                EmployeeHeaderStack(
                  userName: user?.name ?? 'Employee',
                  department: user?.department,
                  designation: user?.designation,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AttendanceStatusCard(),
                ),
                const SizedBox(height: 16),
                
                // 2. Dashboard content wrapped in horizontal padding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Quick Actions & Work Location Info
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const EmployeeQuickActions(),
                            const SizedBox(height: 12),
                            EmployeeInfoCard(
                              title: 'Work Location',
                              icon: Icons.location_on_outlined,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white.withValues(alpha: 0.03) 
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white.withValues(alpha: 0.08) 
                                        : Colors.grey[200]!,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF10B981)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Geofence Active & Protected',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (provider.userWorkLocations.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Assigned Locations:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).brightness == Brightness.dark 
                                              ? Colors.grey[300] 
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: provider.userWorkLocations.map((loc) {
                                          final locActive = loc.isActive;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: locActive 
                                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.1) 
                                                  : Colors.grey.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: locActive 
                                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.25) 
                                                    : Colors.grey.withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.location_on_outlined, 
                                                  size: 12, 
                                                  color: locActive ? const Color(0xFF3B82F6) : Colors.grey
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  loc.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: locActive 
                                                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.blue[300] : Colors.blue[700]) 
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Text(
                                      provider.userWorkLocations.isEmpty
                                          ? 'Standard locations. Ensure you are within the geofence to mark attendance.'
                                          : 'Please ensure you are within one of the geofenced areas above when marking attendance.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.grey[400] 
                                            : Colors.grey[600],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right Column: Stats Grid & Reminders Info
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.5,
                              children: [
                                EmployeeStatCard(
                                  label: 'Present Days',
                                  value: stats.presentToday.toString(),
                                  icon: Icons.check_circle_outline,
                                  iconColor: const Color(0xFF10B981),
                                ),
                                EmployeeStatCard(
                                  label: 'Absent Days',
                                  value: stats.absentToday.toString(),
                                  icon: Icons.cancel_outlined,
                                  iconColor: const Color(0xFFEF4444),
                                ),
                                EmployeeStatCard(
                                  label: 'Late Arrivals',
                                  value: stats.lateCheckins.toString(),
                                  icon: Icons.access_time,
                                  iconColor: const Color(0xFFF59E0B),
                                ),
                                EmployeeStatCard(
                                  label: 'Leave Balance',
                                  value: leaveBalance.toString(),
                                  badgeText: 'Yearly',
                                  icon: Icons.coffee,
                                  iconColor: const Color(0xFF3B82F6),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            EmployeeInfoCard(
                              title: 'Reminders',
                              icon: Icons.info_outline,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildBulletPoint(context, 'Mark before 09:30 AM.'),
                                  const SizedBox(height: 8),
                                  _buildBulletPoint(context, 'Leave 2 days prior.'),
                                  const SizedBox(height: 8),
                                  _buildBulletPoint(context, 'Missed punch-out? Request correction in 2 days.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3.5, backgroundColor: primaryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[300] 
                  : Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class MobileAdminDashboardLandscape extends StatefulWidget {
  const MobileAdminDashboardLandscape({super.key});

  @override
  State<MobileAdminDashboardLandscape> createState() => _MobileAdminDashboardLandscapeState();
}

class _MobileAdminDashboardLandscapeState extends State<MobileAdminDashboardLandscape> {
  final List<Map<String, dynamic>> adminQuickActions = [
    {
      'title': 'Mark Attendance',
      'subtitle': 'Punch In / Out',
      'icon': Icons.fingerprint,
      'color': const Color(0xFF10B981),
      'page': PageType.myAttendance,
    },
    {
      'title': 'Manage Shifts',
      'subtitle': 'Update schedules',
      'icon': Icons.work_outline,
      'color': const Color(0xFF8B5CF6),
      'page': PageType.policyEngine,
    },
    {
      'title': 'Geo Fencing',
      'subtitle': 'Configure site coordinates',
      'icon': Icons.map_outlined,
      'color': const Color(0xFFE11D48),
      'page': PageType.geoFencing,
    },
    {
      'title': 'Add Employee',
      'subtitle': 'Create user profile',
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
      Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true)
          .then((_) {
            if (mounted) {
              context.checkAndShowShiftStartBanner();
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final content = SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmployeeHeaderStack(
                userName: user?.name ?? 'Admin',
                department: user?.department,
                designation: user?.designation,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPISection(provider.stats, provider.trends),
                    const SizedBox(height: 24),

                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    _buildAnalyticsSection(provider),
                  ],
                ),
              ),
            ],
          ),
        );

        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Loading dashboard...",
          child: content,
        );
      }
    );
  }

  Widget _buildKPISection(DashboardStats stats, DashboardTrends trends) {
    final kpis = [
      {
        'title': 'Present Today',
        'value': stats.presentToday.toString(),
        'total': '/ ${stats.totalEmployees}',
        'percentage': trends.present.startsWith('-') ? trends.present : '+${trends.present}',
        'context': 'vs yesterday',
        'isPositive': !trends.present.startsWith('-'),
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Total Employees',
        'value': stats.totalEmployees.toString(),
        'total': 'Registered',
        'percentage': '',
        'context': 'Active Staff',
        'isPositive': true,
        'icon': Icons.people_outline,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Late Check-ins',
        'value': stats.lateCheckins.toString(),
        'total': 'Employees',
        'percentage': trends.late,
        'context': 'vs yesterday',
        'isPositive': trends.late.startsWith('-'),
        'icon': Icons.access_time,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'On Leave',
        'value': '4',
        'total': 'Planned',
        'percentage': '',
        'context': 'Monthly',
        'isPositive': true,
        'icon': Icons.calendar_today,
        'color': const Color(0xFF6366F1),
      },
    ];

    return Row(
      children: kpis.map((data) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
               height: 100, 
               child: StatCard(
                title: data['title'] as String,
                value: data['value'] as String,
                total: data['total'] as String,
                percentage: data['percentage'] as String,
                contextText: data['context'] as String,
                isPositive: data['isPositive'] as bool,
                icon: data['icon'] as IconData,
                baseColor: data['color'] as Color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8, 
          ),
          itemCount: adminQuickActions.length,
          itemBuilder: (context, index) {
            final data = adminQuickActions[index];
            return ActionCard(
              title: data['title'],
              subtitle: data['subtitle'],
              icon: data['icon'],
              color: data['color'],
              onTap: () {
                if (data['page'] != null) {
                  navigateTo(data['page'] as PageType);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(DashboardProvider provider) {
    return Column(
      children: [
         SizedBox(
          height: 300,
          child: TrendsChart(chartData: provider.chartData),
        ),
        const SizedBox(height: 24),
        ActivityFeed(activities: provider.activities),
      ],
    );
  }
}

class MobileHrDashboardLandscape extends StatefulWidget {
  const MobileHrDashboardLandscape({super.key});

  @override
  State<MobileHrDashboardLandscape> createState() => _MobileHrDashboardLandscapeState();
}

class _MobileHrDashboardLandscapeState extends State<MobileHrDashboardLandscape> {
  final List<Map<String, dynamic>> hrQuickActions = [
    {
      'title': 'Mark Attendance',
      'subtitle': 'Punch In / Out',
      'icon': Icons.fingerprint,
      'color': const Color(0xFF10B981),
      'page': PageType.myAttendance,
    },
    {
      'title': 'Add Employee',
      'subtitle': 'Create profile',
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
    {
      'title': 'Live Monitor',
      'subtitle': 'Real-time feed',
      'icon': Icons.admin_panel_settings_outlined,
      'color': const Color(0xFFEF4444),
      'page': PageType.liveAttendance,
    },
    {
      'title': 'Generate Report',
      'subtitle': 'Download CSV',
      'icon': Icons.description_outlined,
      'color': const Color(0xFF10B981),
      'page': PageType.reports,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
      Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true)
          .then((_) {
            if (mounted) {
              context.checkAndShowShiftStartBanner();
            }
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final content = SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmployeeHeaderStack(
                userName: user?.name ?? 'HR Manager',
                department: user?.department,
                designation: user?.designation,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKPISection(provider.stats, provider.trends),
                    const SizedBox(height: 24),

                    _buildQuickActions(),
                    const SizedBox(height: 24),

                    _buildAnalyticsSection(provider),
                  ],
                ),
              ),
            ],
          ),
        );

        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Loading dashboard...",
          child: content,
        );
      }
    );
  }

  Widget _buildKPISection(DashboardStats stats, DashboardTrends trends) {
    final kpis = [
      {
        'title': 'Present Today',
        'value': stats.presentToday.toString(),
        'total': '/ ${stats.totalEmployees}',
        'percentage': trends.present.startsWith('-') ? trends.present : '+${trends.present}',
        'context': 'vs yesterday',
        'isPositive': !trends.present.startsWith('-'),
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Absent Today',
        'value': stats.absentToday.toString(),
        'total': 'Employees',
        'percentage': trends.absent.startsWith('-') ? trends.absent : '+${trends.absent}',
        'context': 'vs yesterday',
        'isPositive': trends.absent.startsWith('-'),
        'icon': Icons.cancel_outlined,
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Late Check-ins',
        'value': stats.lateCheckins.toString(),
        'total': 'Employees',
        'percentage': trends.late,
        'context': 'vs yesterday',
        'isPositive': trends.late.startsWith('-'),
        'icon': Icons.access_time,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'On Leave',
        'value': '4',
        'total': 'Planned',
        'percentage': '',
        'context': 'Monthly',
        'isPositive': true,
        'icon': Icons.calendar_today,
        'color': const Color(0xFF6366F1),
      },
    ];

    return Row(
      children: kpis.map((data) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
               height: 100, 
               child: StatCard(
                title: data['title'] as String,
                value: data['value'] as String,
                total: data['total'] as String,
                percentage: data['percentage'] as String,
                contextText: data['context'] as String,
                isPositive: data['isPositive'] as bool,
                icon: data['icon'] as IconData,
                baseColor: data['color'] as Color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8, 
          ),
          itemCount: hrQuickActions.length,
          itemBuilder: (context, index) {
            final data = hrQuickActions[index];
            return ActionCard(
              title: data['title'],
              subtitle: data['subtitle'],
              icon: data['icon'],
              color: data['color'],
              onTap: () {
                if (data['page'] != null) {
                  navigateTo(data['page'] as PageType);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(DashboardProvider provider) {
    return Column(
      children: [
         SizedBox(
          height: 300,
          child: TrendsChart(chartData: provider.chartData),
        ),
        const SizedBox(height: 24),
        ActivityFeed(activities: provider.activities),
      ],
    );
  }
}
