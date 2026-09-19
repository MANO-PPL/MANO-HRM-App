import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/attendance/widgets/mark_attendance_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_history_tab.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_analytics_tab.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_admin_view.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_header_widget.dart';

class AttendanceTabletPortraitView extends StatefulWidget {
  const AttendanceTabletPortraitView({super.key});

  @override
  State<AttendanceTabletPortraitView> createState() => _AttendanceTabletPortraitViewState();
}

/// Backward compatibility alias for MyAttendanceView
typedef MyAttendanceView = AttendanceTabletPortraitView;

class _AttendanceTabletPortraitViewState extends State<AttendanceTabletPortraitView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _currentIndex = 0;
  bool _hasVisitedMyAttendance = false;

  TabController get _effectiveTabController {
    if (_tabController == null) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(_handleTabChange);
    }
    return _tabController!;
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  void _initTabController() {
    if (_tabController == null) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(_handleTabChange);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _initTabController();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null) return;
    if (_currentIndex != controller.index) {
      setState(() {
        _currentIndex = controller.index;
        if (_currentIndex == 1) {
          _hasVisitedMyAttendance = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    _tabController = null;
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_effectiveTabController.index != index) {
      _effectiveTabController.animateTo(index);
    }
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        if (index == 1) {
          _hasVisitedMyAttendance = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.transparent
          : const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AttendanceHeaderWidget(showTabBar: false),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AttendanceTabBar(
                  controller: _effectiveTabController,
                  onTap: _onTabSelected,
                ),
              ),
            ),
            Visibility(
              visible: _currentIndex == 0,
              maintainState: true,
              maintainAnimation: false,
              maintainSize: false,
              maintainSemantics: false,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: MarkAttendanceMobile(),
              ),
            ),
            if (_hasVisitedMyAttendance || _currentIndex == 1)
              Visibility(
                visible: _currentIndex == 1,
                maintainState: true,
                maintainAnimation: false,
                maintainSize: false,
                maintainSemantics: false,
                child: const AttendanceReportsTabTablet(),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class AttendanceReportsTabTablet extends StatefulWidget {
  const AttendanceReportsTabTablet({super.key});

  @override
  State<AttendanceReportsTabTablet> createState() => _AttendanceReportsTabTabletState();
}

class _AttendanceReportsTabTabletState extends State<AttendanceReportsTabTablet> {
  int _selectedIndex = 0; // 0: History, 1: Analytics, 2: Corrections

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTab('History', 0, Icons.history),
                const SizedBox(width: 32),
                _buildSubTab('Analytics', 1, Icons.analytics_outlined),
                const SizedBox(width: 32),
                _buildSubTab('Correction Requests', 2, Icons.edit_calendar_outlined),
              ],
            ),
          ),
        ),
        
        _selectedIndex == 0 
          ? const AttendanceHistoryTab(shrinkWrap: true, physics: NeverScrollableScrollPhysics()) 
          : _selectedIndex == 1
            ? const AttendanceAnalyticsTab(shrinkWrap: true, physics: NeverScrollableScrollPhysics())
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
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

    final selectedColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA);
    final unselectedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final activeColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: IntrinsicWidth(
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: activeColor),
                  const SizedBox(width: 8),
                  Text(
                    label, 
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, 
                      fontSize: 13,
                      color: activeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2.5,
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

