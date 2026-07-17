import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../widgets/mark_attendance_mobile.dart';
import '../widgets/attendance_history_mobile.dart';
import '../widgets/attendance_analytics_mobile.dart';
import 'package:flutter_application/features/attendance/admin/views/admin_correction_requests.dart';
import '../../widgets/attendance_header_widget.dart';
import '../../../../shared/widgets/loading_screen.dart';

class MobileMyAttendanceContent extends StatefulWidget {
  const MobileMyAttendanceContent({super.key});

  @override
  State<MobileMyAttendanceContent> createState() => _MobileMyAttendanceContentState();
}

class _MobileMyAttendanceContentState extends State<MobileMyAttendanceContent> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        return LoadingScreen(
          isLoading: provider.isLoading && provider.records.isEmpty,
          message: "Loading attendance records...",
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : const Color(0xFFF8F9FA),
            child: DefaultTabController(
              length: 2,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const AttendanceHeaderWidget(showTabBar: false),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: AttendanceTabBar(maxWidth: 480),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final tabController = DefaultTabController.of(context);

                        return _TabContentBuilder(
                          controller: tabController,
                          builder: (context, index) {
                            return index == 0
                                ? const MarkAttendanceMobile()
                                : _MyAttendanceReportsTab();
                          },
                        );
                      },
                    ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sub-tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        
        _selectedIndex == 0 
          ? const AttendanceHistoryMobile(shrinkWrap: true, physics: NeverScrollableScrollPhysics()) 
          : _selectedIndex == 1
            ? const AttendanceAnalyticsMobile(shrinkWrap: true, physics: NeverScrollableScrollPhysics())
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AdminCorrectionRequests(
                  isPersonalView: true,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
      ],
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

class _TabContentBuilder extends StatefulWidget {
  final TabController controller;
  final Widget Function(BuildContext context, int index) builder;

  const _TabContentBuilder({
    required this.controller,
    required this.builder,
  });

  @override
  State<_TabContentBuilder> createState() => _TabContentBuilderState();
}

class _TabContentBuilderState extends State<_TabContentBuilder> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.index;
    widget.controller.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(_TabContentBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleTabChange);
      _currentIndex = widget.controller.index;
      widget.controller.addListener(_handleTabChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (widget.controller.index != _currentIndex) {
      setState(() {
        _currentIndex = widget.controller.index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentIndex);
  }
}
