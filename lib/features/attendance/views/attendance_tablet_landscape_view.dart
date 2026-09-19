import 'package:flutter/material.dart';
import 'package:flutter_application/features/attendance/widgets/mark_attendance_mobile.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_header_widget.dart';
import 'package:flutter_application/features/attendance/views/attendance_tablet_portrait_view.dart';

class AttendanceTabletLandscapeView extends StatefulWidget {
  const AttendanceTabletLandscapeView({super.key});

  @override
  State<AttendanceTabletLandscapeView> createState() => _AttendanceTabletLandscapeViewState();
}

class _AttendanceTabletLandscapeViewState extends State<AttendanceTabletLandscapeView>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.transparent : const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AttendanceHeaderWidget(showTabBar: false),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AttendanceTabBar(
                  controller: _effectiveTabController,
                  onTap: _onTabSelected,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  children: [
                    Visibility(
                      visible: _currentIndex == 0,
                      maintainState: true,
                      maintainAnimation: false,
                      maintainSize: false,
                      maintainSemantics: false,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: AttendanceReportsTabTablet(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
