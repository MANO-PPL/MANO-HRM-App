import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/dashboard_provider.dart';
import '../../../../shared/models/dashboard_model.dart';
import '../../../../shared/navigation/navigation_controller.dart'; 
import '../../../../shared/widgets/loading_screen.dart';
import '../widgets/action_card.dart';
import '../widgets/activity_feed.dart';
import '../widgets/stat_card.dart';
import '../widgets/trends_chart.dart';
import '../../../../shared/services/auth_service.dart';
import '../../widgets/employee_dashboard_widgets.dart';
import '../../../../features/attendance/providers/attendance_provider.dart';
import '../../../../shared/widgets/toast_helper.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
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

  // Quick actions specific to Admin
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
      'subtitle': 'Update work schedules',
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
      'subtitle': 'Create new user profile',
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Fetching dashboard data...",
          child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth >= 900;

            return SingleChildScrollView(
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
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: KPI Cards
                        _buildKPISection(provider.stats, provider.trends, isLandscape),
                        const SizedBox(height: 32),

                        // Row 2: Quick Actions
                        _buildQuickActions(isLandscape),
                        const SizedBox(height: 32),

                        // Row 3: Split View (Chart, Feed, and Anomalies)
                        _buildSplitView(provider, isLandscape),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      );
    }
  );
}

  Widget _buildKPISection(DashboardStats stats, DashboardTrends trends, bool isLandscape) {
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

    if (isLandscape) {
      return Row(
        children: kpis.map((data) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 140,
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
    } else {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 2.2,
        children: kpis.map((data) {
          return StatCard(
            title: data['title'] as String,
            value: data['value'] as String,
            total: data['total'] as String,
            percentage: data['percentage'] as String,
            contextText: data['context'] as String,
            isPositive: data['isPositive'] as bool,
            icon: data['icon'] as IconData,
            baseColor: data['color'] as Color,
          );
        }).toList(),
      );
    }
  }

  Widget _buildQuickActions(bool isLandscape) {
    final actions = adminQuickActions.map((data) {
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
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        if (isLandscape)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.0,
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
          )
        else
          // Portrait: Stack actions one below the other
          Column(
            children: actions.map((card) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: card,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSplitView(DashboardProvider provider, bool isLandscape) {
    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 400,
              child: TrendsChart(chartData: provider.chartData),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 400,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    ActivityFeed(activities: provider.activities),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(
            height: 350,
            child: TrendsChart(chartData: provider.chartData),
          ),
          const SizedBox(height: 32),
          ActivityFeed(activities: provider.activities),
        ],
      );
    }
  }
}
