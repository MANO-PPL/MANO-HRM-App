import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/dashboard_provider.dart';
import '../../../../shared/models/dashboard_model.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import '../widgets/action_card.dart';
import '../widgets/activity_feed.dart';
import '../widgets/stat_card.dart';
import '../widgets/trends_chart.dart';

class HrDashboardView extends StatefulWidget {
  const HrDashboardView({super.key});

  @override
  State<HrDashboardView> createState() => _HrDashboardViewState();
}

class _HrDashboardViewState extends State<HrDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
    });
  }

  // Quick actions specific to HR
  final List<Map<String, dynamic>> hrQuickActions = [
    {
      'title': 'Add Employee',
      'subtitle': 'Create new user profile',
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
    {
      'title': 'Live Monitor',
      'subtitle': 'Real-time attendance',
      'icon': Icons.admin_panel_settings_outlined,
      'color': const Color(0xFFEF4444),
      'page': PageType.liveAttendance,
    },
    {
      'title': 'Generate Report',
      'subtitle': 'Download monthly stats',
      'icon': Icons.description_outlined,
      'color': const Color(0xFF10B981),
      'page': PageType.reports,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: KPI Cards (Wrap or Row based on orientation)
                  _buildKPISection(provider.stats, provider.trends, isLandscape),
                  const SizedBox(height: 32),

                  // Row 2: Quick Actions
                  _buildQuickActions(isLandscape),
                  const SizedBox(height: 32),

                  // Row 3: Trends & Activity split based on orientation
                  _buildAnalyticsSection(provider, isLandscape),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
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
        'title': 'Absent',
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
      // Portrait: 2x2 Grid
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
    final actions = hrQuickActions.map((data) {
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
              crossAxisCount: 3,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.5,
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

  Widget _buildAnalyticsSection(DashboardProvider provider, bool isLandscape) {
    if (isLandscape) {
      // Split layout for landscape
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
                child: ActivityFeed(activities: provider.activities),
              ),
            ),
          ),
        ],
      );
    } else {
      // Column stack for portrait
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
