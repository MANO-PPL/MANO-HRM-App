import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/features/policy_engine/views/policy_engine_tablet_portrait_view.dart';
import 'package:flutter_application/features/geo_fencing/views/geo_fencing_mobile_portrait_view.dart';
import 'package:flutter_application/features/policies/widgets/salary_packages_tab_view.dart';
import 'package:flutter_application/features/leave/widgets/leave_policies_tab.dart';

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
    _currentTab = widget.initialTab ?? policiesTabNotifier.value;
    policiesTabNotifier.addListener(_syncTab);
  }

  @override
  void dispose() {
    policiesTabNotifier.removeListener(_syncTab);
    super.dispose();
  }

  void _syncTab() {
    if (mounted && policiesTabNotifier.value != _currentTab) {
      setState(() => _currentTab = policiesTabNotifier.value);
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
        // Full-Width Mobile Header Strip (Occupies full page from left to right)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                _buildTabPill('shifts', 'Shifts', Icons.access_time_rounded, isDark),
                _buildTabPill('geofencing', 'Geo', Icons.location_on_outlined, isDark),
                _buildTabPill('salary_packages', 'Salary', Icons.layers_outlined, isDark),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF21262D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
                const SizedBox(width: 3),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    switch (tab) {
      case 'geofencing':
        return const MobileGeoFencingContent(key: ValueKey('geofencing'));
      case 'salary_packages':
        return const SalaryPackagesTabView(key: ValueKey('salary_packages'));
      case 'leave_policies':
      case 'leaves':
      case 'leave':
      case 'policies':
        return const LeavePoliciesTab(key: ValueKey('leave_policies'));
      case 'shifts':
      default:
        return const PolicyEngineView(key: ValueKey('shifts'));
    }
  }
}

// [upd:2026-04-09T08:30:00+05:30]
