import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
import 'package:flutter_application/features/attendance/tablet/widgets/correction_request_dialog.dart';
import 'package:flutter_application/features/attendance/models/correction_request.dart';

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
      Provider.of<AttendanceProvider>(context, listen: false)
          .fetchRecords(DateTime.now(), forceRefresh: true)
          .then((_) {
            if (mounted) {
              context.checkAndShowShiftStartBanner();
            }
          });
    });
  }

  // Quick actions specific to HR
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
    final user = context.watch<AuthService>().user;
    final attendanceProvider = context.watch<AttendanceProvider>();
    final missedPunchDate = attendanceProvider.missedPunchDate;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Fetching HR dashboard...",
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
                    userName: user?.name ?? 'HR Manager',
                    department: user?.department,
                    designation: user?.designation,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (missedPunchDate != null) ...[
                          _buildMissedPunchBanner(context, missedPunchDate, attendanceProvider),
                          const SizedBox(height: 24),
                        ],
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
                  ),
                ],
              ),
            );
          },
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
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 2.0,
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

  Widget _buildMissedPunchBanner(BuildContext context, DateTime missedDate, AttendanceProvider provider) {
    final dateLabel = DateFormat('EEE, MMM d').format(missedDate);
    final deadlineDays = provider.correctionDeadlineDays;
    final expiry = DateTime(missedDate.year, missedDate.month, missedDate.day)
        .add(Duration(days: deadlineDays + 1));
    final hoursLeft = expiry.difference(DateTime.now()).inHours;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final daysLeftLabel = hoursLeft <= 0 ? 'Expired' : daysLeft == 0 ? 'Last chance today' : '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    final isExpired = hoursLeft <= 0;

    return InkWell(
      onTap: isExpired
          ? null
          : () {
              CorrectionRequestDialog.show(
                context,
                date: missedDate,
                attendanceId: null,
                type: CorrectionType.missedPunch,
              ).then((_) => provider.clearMissedPunch());
            },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isExpired
                ? [Colors.red.shade900, Colors.red.shade700]
                : [const Color(0xFFEA580C), const Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isExpired ? Colors.red : Colors.orange).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired ? Icons.block_rounded : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpired ? 'Missed Punch — Deadline Passed' : '⚠️  Missed Time-Out Detected',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isExpired
                        ? 'No time-out recorded for $dateLabel. The correction window has expired.'
                        : 'No time-out recorded for $dateLabel ($daysLeftLabel).',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!isExpired) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  CorrectionRequestDialog.show(
                    context,
                    date: missedDate,
                    attendanceId: null,
                    type: CorrectionType.missedPunch,
                  ).then((_) => provider.clearMissedPunch());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEA580C),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Fix Now',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
