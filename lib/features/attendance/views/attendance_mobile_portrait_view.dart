import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/attendance/core/attendance_provider.dart';
import 'package:flutter_application/features/attendance/widgets/mark_attendance_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_history_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_analytics_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_admin_view.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_header_widget.dart';

class MobileMyAttendanceContent extends StatefulWidget {
  const MobileMyAttendanceContent({super.key});

  @override
  State<MobileMyAttendanceContent> createState() => _MobileMyAttendanceContentState();
}

class _MobileMyAttendanceContentState extends State<MobileMyAttendanceContent>
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
      child: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: () async {
          final att = Provider.of<AttendanceProvider>(context, listen: false);
          await Future.wait([
            att.fetchRecords(DateTime.now(), forceRefresh: true),
            att.fetchShiftPolicy(),
            att.checkMissedPunch(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 19),
                    child: AttendanceHeaderWidget(showTabBar: false),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: AttendanceTabBar(
                          controller: _effectiveTabController,
                          onTap: _onTabSelected,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Visibility(
                visible: _currentIndex == 0,
                maintainState: true,
                maintainAnimation: false,
                maintainSize: false,
                maintainSemantics: false,
                child: const MarkAttendanceMobile(),
              ),
              if (_hasVisitedMyAttendance || _currentIndex == 1)
                Visibility(
                  visible: _currentIndex == 1,
                  maintainState: true,
                  maintainAnimation: false,
                  maintainSize: false,
                  maintainSemantics: false,
                  child: _MyAttendanceReportsTab(),
                ),
            ],
          ),
        ),
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sub-tabs matching Attendance-Web
        Container(
          margin: const EdgeInsets.only(left: 12, right: 12, top: 2, bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTab('History', 0, Icons.history_rounded),
                const SizedBox(width: 16),
                _buildSubTab('Analytics', 1, Icons.analytics_outlined),
                const SizedBox(width: 16),
                _buildSubTab('Correction Requests', 2, Icons.edit_calendar_outlined),
              ],
            ),
          ),
        ),
        
        _selectedIndex == 0 
          ? const AttendanceHistoryMobile(shrinkWrap: true, physics: NeverScrollableScrollPhysics()) 
          : _selectedIndex == 1
            ? const AttendanceAnalyticsMobile(shrinkWrap: true, physics: NeverScrollableScrollPhysics())
            : const Padding(
                padding: EdgeInsets.fromLTRB(12, 2, 12, 6),
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

    // Standardized Tab Colors matching Attendance-Web
    final selectedColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final unselectedColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final activeColor = isSelected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: IntrinsicWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: activeColor),
                  const SizedBox(width: 6),
                  Text(
                    label, 
                    style: GoogleFonts.poppins(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, 
                      fontSize: 12,
                      color: activeColor,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// commit-marker: 2026-02-17T11:00:00+05:30

// [mod:2026-02-17T14:00:00+05:30]

// [rev:2026-08-24T13:30:00+05:30]
