import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../../../../shared/services/dashboard_provider.dart'; // Import Provider
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/dashboard_model.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../tablet/widgets/stat_card.dart';
import '../../tablet/widgets/activity_feed.dart';
import '../../tablet/widgets/trends_chart.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import 'employee_dashboard_mobile.dart';
import '../../../../shared/widgets/loading_screen.dart';
import '../../widgets/employee_dashboard_widgets.dart';
import '../../../../features/attendance/providers/attendance_provider.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../features/attendance/mobile/widgets/correction_request_dialog_mobile.dart';
import '../../../../features/attendance/models/correction_request.dart';

class MobileDashboardContent extends StatelessWidget {
  const MobileDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;

    if (user == null) {
      return const LoadingScreen(message: "Authenticating...");
    }

    if (user.isEmployee) {
      return const MobileEmployeeDashboardContent();
    }
    if (user.isHr) {
      return const MobileHrDashboardContent();
    }
    return const MobileAdminDashboardContent();
  }
}

class MobileAdminDashboardContent extends StatefulWidget {
  const MobileAdminDashboardContent({super.key});

  @override
  State<MobileAdminDashboardContent> createState() =>
      _MobileAdminDashboardContentState();
}

class _MobileAdminDashboardContentState
    extends State<MobileAdminDashboardContent> {
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
      'icon': Icons.work_outline,
      'color': const Color(0xFF8B5CF6),
      'page': PageType.policyEngine,
    },
    {
      'title': 'Geo Fencing',
      'icon': Icons.map_outlined,
      'color': const Color(0xFFE11D48),
      'page': PageType.geoFencing,
    },
    {
      'title': 'Add Employee',
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(
        context,
        listen: false,
      ).fetchDashboardData();
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
    final attendanceProvider = context.watch<AttendanceProvider>();
    final missedPunchDate = attendanceProvider.missedPunchDate;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

        final content = MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: EmployeeHeaderStack(
                  userName: user?.name ?? 'Admin',
                  department: user?.department,
                  designation: user?.designation,
                ),
              ),
              if (missedPunchDate != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildMissedPunchBanner(context, missedPunchDate, attendanceProvider),
                  ),
                ),
              // 1. KPI Section (Grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMobileKPIStack(
                      provider.stats,
                      provider.trends,
                      false,
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),

              // 2. Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: adminQuickActions.map((action) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildQuickActionItem(
                              context,
                              action['title'],
                              action['icon'],
                              action['color'],
                              () {
                                if (action['page'] != null) {
                                  navigateTo(action['page'] as PageType);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 3. Analytics
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chart
                    SizedBox(
                      height: 300,
                      child: TrendsChart(chartData: provider.chartData),
                    ),
                    const SizedBox(height: 24),
                    // Activity Feed
                    ActivityFeed(activities: provider.activities),
                    const SizedBox(height: 40),
                  ]),
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
      },
    );
  }

  Widget _buildMobileKPIStack(
    DashboardStats stats,
    DashboardTrends trends,
    bool isHr,
  ) {
    final kpis = [
      {
        'title': 'Present Today',
        'value': stats.presentToday.toString(),
        'total': '/ ${stats.totalEmployees}',
        'percentage': trends.present.startsWith('-')
            ? trends.present
            : '+${trends.present}',
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
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
              CorrectionRequestDialogMobile.show(
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
                  CorrectionRequestDialogMobile.show(
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

class MobileHrDashboardContent extends StatefulWidget {
  const MobileHrDashboardContent({super.key});

  @override
  State<MobileHrDashboardContent> createState() =>
      _MobileHrDashboardContentState();
}

class _MobileHrDashboardContentState extends State<MobileHrDashboardContent> {
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
      'icon': Icons.person_add_outlined,
      'color': const Color(0xFF6366F1),
      'page': PageType.employees,
    },
    {
      'title': 'Live Monitor',
      'icon': Icons.admin_panel_settings_outlined,
      'color': const Color(0xFFEF4444),
      'page': PageType.liveAttendance,
    },
    {
      'title': 'Generate Report',
      'icon': Icons.description_outlined,
      'color': const Color(0xFF10B981),
      'page': PageType.reports,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(
        context,
        listen: false,
      ).fetchDashboardData();
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
    final attendanceProvider = context.watch<AttendanceProvider>();
    final missedPunchDate = attendanceProvider.missedPunchDate;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

        final content = MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: EmployeeHeaderStack(
                  userName: user?.name ?? 'HR Manager',
                  department: user?.department,
                  designation: user?.designation,
                ),
              ),
              if (missedPunchDate != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildMissedPunchBanner(context, missedPunchDate, attendanceProvider),
                  ),
                ),
              // 1. KPI Section (Grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMobileKPIStack(provider.stats, provider.trends),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),

              // 2. Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: hrQuickActions.map((action) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildQuickActionItem(
                              context,
                              action['title'],
                              action['icon'],
                              action['color'],
                              () {
                                if (action['page'] != null) {
                                  navigateTo(action['page'] as PageType);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 3. Analytics
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chart
                    SizedBox(
                      height: 300,
                      child: TrendsChart(chartData: provider.chartData),
                    ),
                    const SizedBox(height: 24),
                    // Activity Feed
                    ActivityFeed(activities: provider.activities),
                    const SizedBox(height: 40),
                  ]),
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
      },
    );
  }

  Widget _buildMobileKPIStack(DashboardStats stats, DashboardTrends trends) {
    final kpis = [
      {
        'title': 'Present Today',
        'value': stats.presentToday.toString(),
        'total': '/ ${stats.totalEmployees}',
        'percentage': trends.present.startsWith('-')
            ? trends.present
            : '+${trends.present}',
        'context': 'vs yesterday',
        'isPositive': !trends.present.startsWith('-'),
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Absent Today',
        'value': stats.absentToday.toString(),
        'total': 'Employees',
        'percentage': trends.absent.startsWith('-')
            ? trends.absent
            : '+${trends.absent}',
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

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
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
              CorrectionRequestDialogMobile.show(
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
                  CorrectionRequestDialogMobile.show(
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

Widget _buildQuickActionItem(
  BuildContext context,
  String title,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
  return GlassContainer(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
