import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/policy_engine/views/policy_engine_tablet_portrait_view.dart';
import 'package:flutter_application/features/geo_fencing/views/geo_fencing_tablet_portrait_view.dart';
import 'package:flutter_application/features/leave/widgets/leave_policies_tab.dart';

/// PoliciesTabletLandscapeView - Tablet Landscape View
/// Replicates Attendance-Web PolicyManagement.jsx exactly:
/// 3-tab unified hub: Work Shifts, Geofence Zones, and Leave Policies.
/// Gracefully redirects salary package routes to the Payroll module.
class PoliciesTabletLandscapeView extends StatefulWidget {
  final String? initialTab;
  const PoliciesTabletLandscapeView({super.key, this.initialTab});

  @override
  State<PoliciesTabletLandscapeView> createState() => _PoliciesTabletLandscapeViewState();
}

class _PoliciesTabletLandscapeViewState extends State<PoliciesTabletLandscapeView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  static const List<String> _tabs = ['shifts', 'geofencing', 'leave_policies'];

  String _normalizeTab(String tab) {
    if (tab == 'leave_policies' || tab == 'leaves' || tab == 'leave' || tab == 'policies') {
      return 'leave_policies';
    }
    if (tab == 'geofencing' || tab == 'geofence') {
      return 'geofencing';
    }
    return 'shifts';
  }

  void _ensureTabController() {
    if (_tabController == null) {
      final tab = widget.initialTab ?? policiesTabNotifier.value;
      if (tab == 'salary_packages' || tab == 'packages') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigateTo(PageType.payroll);
        });
      }
      final normalized = _normalizeTab(tab);
      final initialIndex = _tabs.indexOf(normalized);
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: initialIndex != -1 ? initialIndex : 0,
      );
      _tabController!.addListener(_handleTabSelection);
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureTabController();
    policiesTabNotifier.addListener(_handleNotifierChange);
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureTabController();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    policiesTabNotifier.removeListener(_handleNotifierChange);
    super.dispose();
  }

  void _handleTabSelection() {
    final controller = _tabController;
    if (controller != null && !controller.indexIsChanging && mounted) {
      final selectedKey = _tabs[controller.index];
      if (policiesTabNotifier.value != selectedKey) {
        policiesTabNotifier.value = selectedKey;
      }
      setState(() {});
    }
  }

  void _handleNotifierChange() {
    final controller = _tabController;
    if (mounted && controller != null) {
      final tab = policiesTabNotifier.value;
      if (tab == 'salary_packages' || tab == 'packages') {
        navigateTo(PageType.payroll);
        return;
      }
      final normalized = _normalizeTab(tab);
      final index = _tabs.indexOf(normalized);
      if (index != -1 && index != controller.index) {
        controller.animateTo(index);
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant PoliciesTabletLandscapeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureTabController();
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      final normalized = _normalizeTab(widget.initialTab!);
      final index = _tabs.indexOf(normalized);
      if (index != -1 && _tabController != null && index != _tabController!.index) {
        _tabController!.animateTo(index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureTabController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs Strip - Replicating Web PolicyManagement.jsx Design System
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 520,
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF21262D) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: isDark ? Colors.white : const Color(0xFF6366F1),
                    unselectedLabelColor: isDark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF64748B),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time_rounded, size: 16),
                            SizedBox(width: 8),
                            Text("Work Shifts"),
                          ],
                        ),
                      ),
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16),
                            SizedBox(width: 8),
                            Text("Geofence Zones"),
                          ],
                        ),
                      ),
                      Tab(
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_outlined, size: 16),
                            SizedBox(width: 8),
                            Text("Leave Policies"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              PolicyEngineView(key: ValueKey('shifts')),
              GeoFencingView(key: ValueKey('geofencing')),
              LeavePoliciesTab(key: ValueKey('leave_policies')),
            ],
          ),
        ),
      ],
    );
  }
}
