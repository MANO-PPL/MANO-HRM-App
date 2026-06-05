import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../widgets/mark_attendance_mobile.dart';
import '../../widgets/attendance_history_tab.dart';
import '../../widgets/attendance_analytics_tab.dart';
import 'package:flutter_application/features/attendance/admin/views/admin_correction_requests.dart';
import '../../widgets/attendance_header_widget.dart';
import '../../../../shared/widgets/loading_screen.dart';

class MobileMyAttendanceContent extends StatefulWidget {
  const MobileMyAttendanceContent({super.key});

  @override
  State<MobileMyAttendanceContent> createState() => _MobileMyAttendanceContentState();
}

class _MobileMyAttendanceContentState extends State<MobileMyAttendanceContent> {
  // Logic has been moved to MarkAttendanceMobile

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        return LoadingScreen(
          isLoading: provider.isLoading,
          message: "Loading attendance records...",
          child: Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.transparent
              : const Color(0xFFF8F9FA),
          child: DefaultTabController(
            length: 2, // Reduced to 2
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                    const SliverToBoxAdapter(
                      child: AttendanceHeaderWidget(showTabBar: false),
                    ),
                    // Render the tab bar inside a standard padding container
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: AttendanceTabBar(maxWidth: 480),
                          ),
                        ),
                      ),
                    ),
                  ];
              },
              body: TabBarView(
                children: [
                  // Tab 1: Mark Attendance
                  const MarkAttendanceMobile(),

                  // Tab 2: My Attendance (Sub-tabs: History / Analytics)
                  _MyAttendanceReportsTab(),
                ],
              ),
            ),
          ),
        ),
       );
      },
    );
  }
}

class _MyAttendanceReportsTab extends StatefulWidget {
  @override
  State<_MyAttendanceReportsTab> createState() => _MyAttendanceReportsTabState();
}

class _MyAttendanceReportsTabState extends State<_MyAttendanceReportsTab> {
  int _selectedIndex = 0; // 0: History, 1: Analytics, 2: Corrections

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Sub-tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTab('History', 0, Icons.history),
                  const SizedBox(width: 24),
                  _buildSubTab('Analytics', 1, Icons.analytics_outlined),
                  const SizedBox(width: 24),
                  _buildSubTab('Corrections', 2, Icons.edit_calendar_outlined),
                ],
              ),
            ),
          ),
          
          
          Expanded(
            child: _selectedIndex == 0 
              ? const AttendanceHistoryTab() 
              : _selectedIndex == 1
                ? const AttendanceAnalyticsTab()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const AdminCorrectionRequests(isPersonalView: true),
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildSubTab(String label, int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Standardized Tab Colors
    final selectedColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final activeColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: activeColor),
              const SizedBox(width: 8),
              Text(
                label, 
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, 
                  fontSize: 12,
                  color: activeColor
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 80,
            color: isSelected ? selectedColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
