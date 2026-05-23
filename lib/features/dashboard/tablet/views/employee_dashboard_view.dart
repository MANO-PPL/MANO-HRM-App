import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/dashboard_provider.dart';
import '../../../../shared/navigation/navigation_controller.dart'; 
import '../../widgets/employee_dashboard_widgets.dart';

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
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxWidth < 900;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch for full width
                children: [
                  // 1. Hero Section
                  EmployeeHero(
                    userName: user?.name ?? 'Employee',
                    onAttendanceTap: () => navigateTo(PageType.myAttendance),
                    onHolidayTap: () => navigateTo(PageType.leavesAndHolidays),
                    onLeaveTap: () => navigateTo(PageType.leavesAndHolidays),
                  ),
                  const SizedBox(height: 32),

                  // 2. Stats Section
                  if (isPortrait)
                    // Tablet Portrait: 2x2 Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 2.0, 
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
                        const EmployeeStatCard(
                          label: 'Leave Balance',
                          value: '8',
                          badgeText: 'Yearly',
                          icon: Icons.coffee,
                          iconColor: Color(0xFF3B82F6),
                        ),
                      ],
                    )
                  else
                    // Tablet Landscape: 1 Row
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
                        const SizedBox(width: 24),
                        Expanded(
                          child: EmployeeStatCard(
                            label: 'Absent Days',
                            value: stats.absentToday.toString(),
                            icon: Icons.cancel_outlined,
                            iconColor: const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: EmployeeStatCard(
                            label: 'Late Arrivals',
                            value: stats.lateCheckins.toString(),
                            icon: Icons.access_time,
                            iconColor: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: EmployeeStatCard(
                            label: 'Leave Balance',
                            value: '8',
                            badgeText: 'Yearly',
                            icon: Icons.coffee,
                            iconColor: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 32),

                  // 3. Info Cards
                  if (isPortrait)
                    // Tablet Portrait: Stacked
                    Column(
                      children: [
                        EmployeeInfoCard(
                          title: 'Your Work Location',
                          icon: Icons.location_on_outlined,
                          child: _buildLocationText(context),
                        ),
                        const SizedBox(height: 24),
                        EmployeeInfoCard(
                          title: 'Policies & Reminders',
                          icon: Icons.info_outline,
                          child: _buildPolicyContent(context),
                        ),
                      ],
                    )
                  else
                    // Tablet Landscape: Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: EmployeeInfoCard(
                            title: 'Your Work Location',
                            icon: Icons.location_on_outlined,
                            child: _buildLocationText(context),
                          ),
                        ),
                        const SizedBox(width: 24),
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
            );
          },
        );
      }
    );
  }

  Widget _buildLocationText(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withValues(alpha: 0.1) 
              : Colors.grey[300]!,
        ),
      ),
      child: Text(
        'You are currently assigned to standard work locations. Please ensure you are within the geofenced area when marking attendance.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.grey[400] 
              : Colors.grey[700],
          height: 1.5,
        ),
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
      ],
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3, backgroundColor: Theme.of(context).primaryColor),
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
