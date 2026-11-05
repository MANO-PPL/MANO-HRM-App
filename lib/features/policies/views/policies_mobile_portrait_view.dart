import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/policy_engine/views/policy_engine_tablet_portrait_view.dart';
import 'package:flutter_application/features/geo_fencing/views/geo_fencing_mobile_portrait_view.dart';
import 'package:flutter_application/features/leave/widgets/leave_policies_tab.dart';

/// PoliciesMobileView - Mobile Portrait View
/// Replicates Attendance-Web PolicyManagement-mv.jsx exactly:
/// 3-tab unified hub: Work Shifts, Geofence Zones, and Leave Policies.
/// Gracefully redirects salary package routes to the Payroll module.
class PoliciesMobileView extends StatefulWidget {
  final String? initialTab;
  const PoliciesMobileView({super.key, this.initialTab});

  @override
  State<PoliciesMobileView> createState() => _PoliciesMobileViewState();
}

class _PoliciesMobileViewState extends State<PoliciesMobileView> {
  late String _currentTab;

  @override
  void initState() {
    super.initState();
    final tab = widget.initialTab ?? policiesTabNotifier.value;
    if (tab == 'salary_packages' || tab == 'packages') {
      _currentTab = 'shifts';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateTo(PageType.payroll);
      });
    } else {
      _currentTab = _normalizeTab(tab);
    }
    policiesTabNotifier.addListener(_syncTab);
  }

  @override
  void dispose() {
    policiesTabNotifier.removeListener(_syncTab);
    super.dispose();
  }

  String _normalizeTab(String tab) {
    if (tab == 'leave_policies' || tab == 'leaves' || tab == 'leave' || tab == 'policies') {
      return 'leave_policies';
    }
    if (tab == 'geofencing' || tab == 'geofence') {
      return 'geofencing';
    }
    return 'shifts';
  }

  void _syncTab() {
    if (mounted) {
      final tab = policiesTabNotifier.value;
      if (tab == 'salary_packages' || tab == 'packages') {
        navigateTo(PageType.payroll);
        return;
      }
      final normalized = _normalizeTab(tab);
      if (normalized != _currentTab) {
        setState(() => _currentTab = normalized);
      }
    }
  }

  void _setTab(String tab) {
    setState(() => _currentTab = tab);
    policiesTabNotifier.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mobile Tabs Strip - Matching Web PolicyManagement-mv.jsx
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
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
            child: Row(
              children: [
                _buildTabPill('shifts', 'Shifts', Icons.access_time_rounded, isDark),
                _buildTabPill('geofencing', 'Geofence', Icons.location_on_outlined, isDark),
                _buildTabPill('leave_policies', 'Leaves', Icons.event_available_outlined, isDark),
              ],
            ),
          ),
        ),

        // Active Tab Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildTabContent(_currentTab),
          ),
        ),
      ],
    );
  }

  Widget _buildTabPill(String tabKey, String label, IconData icon, bool isDark) {
    final isSelected = _currentTab == tabKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setTab(tabKey),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                      : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'geofencing':
        return const MobileGeoFencingContent(key: ValueKey('geofencing'));
      case 'leave_policies':
        return const LeavePoliciesTab(key: ValueKey('leave_policies'));
      case 'shifts':
      default:
        return const PolicyEngineView(key: ValueKey('shifts'));
    }
  }
}
