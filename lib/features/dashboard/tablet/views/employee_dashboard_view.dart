import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/services/dashboard_provider.dart';
import 'package:flutter_application/features/attendance/providers/attendance_provider.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import '../../widgets/employee_dashboard_widgets.dart';
import '../../../../shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/attendance/tablet/widgets/correction_request_dialog.dart';
import 'package:flutter_application/features/attendance/models/correction_request.dart';

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
    final attendanceProvider = context.watch<AttendanceProvider>();
    final missedPunchDate = attendanceProvider.missedPunchDate;

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

        return LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxWidth < 900;

            return SingleChildScrollView(
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
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: AttendanceStatusCard(),
                  ),
                  const SizedBox(height: 16),

                  if (missedPunchDate != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildMissedPunchBanner(context, missedPunchDate, attendanceProvider),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Dashboard content wrapped in horizontal padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick Actions
                        const EmployeeQuickActions(),
                        const SizedBox(height: 16),

                        // Stats Section
                        if (isPortrait)
                          // Tablet Portrait: 2x2 Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.2, 
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
                          )
                        else
                          // Tablet Landscape: 1 Row with 4 Columns
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: EmployeeStatCard(
                                  label: 'Absent Days',
                                  value: stats.absentToday.toString(),
                                  icon: Icons.cancel_outlined,
                                  iconColor: const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: EmployeeStatCard(
                                  label: 'Late Arrivals',
                                  value: stats.lateCheckins.toString(),
                                  icon: Icons.access_time,
                                  iconColor: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: EmployeeStatCard(
                                  label: 'Leave Balance',
                                  value: leaveBalance.toString(),
                                  badgeText: 'Yearly',
                                  icon: Icons.coffee,
                                  iconColor: const Color(0xFF3B82F6),
                                ),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 16),

                        // Info Cards Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: EmployeeInfoCard(
                                title: 'Your Work Location',
                                icon: Icons.location_on_outlined,
                                child: _buildLocationText(context, provider),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: EmployeeInfoCard(
                                title: 'Policies & Reminders',
                                icon: Icons.info_outline,
                                child: _buildPolicyContent(context),
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
        );
      }
    );
  }

  Widget _buildLocationText(BuildContext context, DashboardProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                ? 'You are currently assigned to standard work locations. Please ensure you are within the geofenced area when marking attendance.'
                : 'Please ensure you are within one of the geofenced areas above when marking attendance.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[400] 
                  : Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(context, 'Mark your attendance before 09:30 AM to avoid late remarks.'),
        const SizedBox(height: 12),
        _buildBulletPoint(context, 'Apply for leave at least 2 days in advance.'),
        const SizedBox(height: 12),
        _buildBulletPoint(context, '⚠️ Missed a punch-out? Submit a correction request via the Attendance page within 2 days to avoid marked absences.'),
      ],
    );
  }

  Widget _buildMissedPunchBanner(BuildContext context, DateTime missedDate, AttendanceProvider provider) {
    final dateLabel = DateFormat('EEE, MMM d').format(missedDate);
    final deadlineDays = provider.correctionDeadlineDays;
    // Expiry = end-of-day on (missedDate + deadlineDays days)
    final expiry = DateTime(missedDate.year, missedDate.month, missedDate.day)
        .add(Duration(days: deadlineDays + 1)); // +1 so the full last day counts
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

  Widget _buildBulletPoint(BuildContext context, String text) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3.5, backgroundColor: primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[300] 
                  : Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
