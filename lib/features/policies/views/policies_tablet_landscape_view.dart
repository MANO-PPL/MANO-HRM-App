import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/policy_engine/views/policy_engine_tablet_portrait_view.dart';
import 'package:flutter_application/features/geo_fencing/views/geo_fencing_tablet_portrait_view.dart';
import 'package:flutter_application/features/policies/widgets/salary_packages_tab_view.dart';
import 'package:flutter_application/features/leave/widgets/leave_policies_tab.dart';

class PoliciesTabletLandscapeView extends StatefulWidget {
  final String? initialTab;
  const PoliciesTabletLandscapeView({super.key, this.initialTab});

  @override
  State<PoliciesTabletLandscapeView> createState() => _PoliciesTabletLandscapeViewState();
}

class _PoliciesTabletLandscapeViewState extends State<PoliciesTabletLandscapeView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  static const List<String> _tabs = ['shifts', 'geofencing', 'salary_packages', 'leave_policies'];

  void _ensureTabController() {
    if (_tabController == null) {
      final initialTab = widget.initialTab ?? policiesTabNotifier.value;
      final initialIndex = _tabs.indexOf(initialTab);
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
      final index = _tabs.indexOf(policiesTabNotifier.value);
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
      final index = _tabs.indexOf(widget.initialTab!);
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
        // Full-Width Edge-to-Edge Header Bar (Occupies full page from left to right)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : Colors.white,
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: isDark ? Colors.white : const Color(0xFF5B60F6),
              unselectedLabelColor: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  height: 38,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.access_time_rounded, size: 16),
                        SizedBox(width: 8),
                        Text("Shift Management"),
                      ],
                    ),
                  ),
                ),
                Tab(
                  height: 38,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.location_on_outlined, size: 16),
                        SizedBox(width: 8),
                        Text("Geo Fencing"),
                      ],
                    ),
                  ),
                ),
                Tab(
                  height: 38,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.payments_outlined, size: 16),
                        SizedBox(width: 8),
                        Text("Salary Packages"),
                      ],
                    ),
                  ),
                ),
                Tab(
                  height: 38,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.event_available_outlined, size: 16),
                        SizedBox(width: 8),
                        Text("Leave Policies"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              SalaryPackagesTabView(key: ValueKey('salary_packages')),
              LeavePoliciesTab(key: ValueKey('leave_policies')),
            ],
          ),
        ),
      ],
    );
  }
}
