import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/views/leave_mobile_portrait_view.dart';
import 'package:flutter_application/features/leave/views/leave_tablet_portrait_view.dart';
import 'package:flutter_application/features/leave/views/leave_tablet_landscape_view.dart';
import 'package:flutter_application/features/holidays/core/holiday_service.dart';
import 'package:flutter_application/features/holidays/widgets/holidays_tab_view.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';

class LeavePage extends StatefulWidget {
  final String initialTab;

  const LeavePage({super.key, this.initialTab = 'holidays'});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> with TickerProviderStateMixin {
  late String _activeTab;
  TabController? _tabController;

  List<String> _getTabs(bool isAdmin) => const ['holidays', 'leaves'];

  void _ensureTabController(bool isAdmin) {
    final tabs = _getTabs(isAdmin);
    if (_tabController == null || _tabController!.length != tabs.length) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.removeListener(_handleTabSelection);
      _tabController?.dispose();

      int initialIndex = tabs.indexOf(_activeTab);
      if (initialIndex == -1) initialIndex = oldIndex.clamp(0, tabs.length - 1);

      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: initialIndex,
      );
      _tabController!.addListener(_handleTabSelection);
    }
  }

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    if (holidaysAndLeaveTabNotifier.value.isNotEmpty && widget.initialTab == 'holidays') {
      _activeTab = holidaysAndLeaveTabNotifier.value;
    }
    holidaysAndLeaveTabNotifier.addListener(_syncTab);
  }

  @override
  void reassemble() {
    super.reassemble();
    final authService = Provider.of<AuthService>(context, listen: false);
    _ensureTabController(authService.user?.isAdmin ?? false);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    holidaysAndLeaveTabNotifier.removeListener(_syncTab);
    super.dispose();
  }

  void _handleTabSelection() {
    final controller = _tabController;
    if (controller != null && !controller.indexIsChanging && mounted) {
      final isAdmin = Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;
      final tabs = _getTabs(isAdmin);
      if (controller.index < tabs.length) {
        final newTab = tabs[controller.index];
        if (_activeTab != newTab) {
          setState(() => _activeTab = newTab);
          holidaysAndLeaveTabNotifier.value = newTab;
        }
      }
    }
  }

  void _syncTab() {
    if (mounted && holidaysAndLeaveTabNotifier.value != _activeTab) {
      final newTab = holidaysAndLeaveTabNotifier.value;
      final isAdmin = Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;
      final tabs = _getTabs(isAdmin);
      final index = tabs.indexOf(newTab);
      setState(() => _activeTab = newTab);
      if (index != -1 && _tabController != null && _tabController!.index != index) {
        _tabController!.animateTo(index);
      }
    }
  }

  void _setTab(String tabId) {
    if (_activeTab != tabId) {
      setState(() => _activeTab = tabId);
      holidaysAndLeaveTabNotifier.value = tabId;
      final isAdmin = Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;
      final tabs = _getTabs(isAdmin);
      final index = tabs.indexOf(tabId);
      if (index != -1 && _tabController != null && _tabController!.index != index) {
        _tabController!.animateTo(index);
      }
    }
  }

  @override
  void didUpdateWidget(covariant LeavePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _setTab(widget.initialTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAdmin = authService.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _ensureTabController(isAdmin);

    final screenWidth = MediaQuery.of(context).size.width;
    final orientation = MediaQuery.of(context).orientation;
    final bool isMobilePortrait = screenWidth < 600 && orientation == Orientation.portrait;

    final double horizontalPadding;
    if (screenWidth < 600) {
      horizontalPadding = isMobilePortrait ? 10 : 14;
    } else if (orientation == Orientation.portrait) {
      horizontalPadding = 20;
    } else {
      horizontalPadding = 24;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Pill Styled Full Width Tab Bar (Matching Attendance, DAR, Payroll, Policies & Feedback)
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 2),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobilePortrait ? 3 : 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    final tabs = _getTabs(isAdmin);
                    if (index < tabs.length) {
                      _setTab(tabs[index]);
                    }
                  },
                  labelPadding: EdgeInsets.symmetric(horizontal: isMobilePortrait ? 2 : 4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    borderRadius: BorderRadius.circular(isMobilePortrait ? 7 : 8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white : const Color(0xFF4F46E5),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: isMobilePortrait ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: isMobilePortrait ? 11.5 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(
                      height: isMobilePortrait ? 34 : 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: isMobilePortrait ? 14 : 16),
                            SizedBox(width: isMobilePortrait ? 5 : 8),
                            const Text("Holidays List"),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: isMobilePortrait ? 34 : 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: isMobilePortrait ? 14 : 16),
                            SizedBox(width: isMobilePortrait ? 5 : 8),
                            Text(isAdmin ? "Leave Requests" : "Leave"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Body Content
            Expanded(
              child: _buildActiveTabContent(authService),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(AuthService authService) {
    if (_activeTab == 'holidays') {
      return HolidaysTabView(
        holidayService: HolidayService(authService.dio),
      );
    }

    // Default: 'leaves' tab rendered responsively
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return const LeaveMobileView();
        }
        return OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return const LeaveTabletPortrait();
            } else {
              return const LeaveTabletLandscape();
            }
          },
        );
      },
    );
  }
}

// Alias for compatibility
typedef LeaveView = LeavePage;
