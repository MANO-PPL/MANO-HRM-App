import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/features/leave/core/leave_service.dart';
import 'package:flutter_application/features/leave/widgets/adjust_balance_dialog.dart';
import 'package:flutter_application/features/employees/core/employee_model.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class LeavePoliciesTab extends StatefulWidget {
  const LeavePoliciesTab({super.key});

  @override
  State<LeavePoliciesTab> createState() => _LeavePoliciesTabState();
}

class _LeavePoliciesTabState extends State<LeavePoliciesTab> {
  final _searchController = TextEditingController();
  final _staffSearchController = TextEditingController();
  int? _selectedPolicyId;
  int _activeSubTab = 0; // 0: Policy Rules, 1: Staff Assignment

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      provider.fetchMyLeaveBalancesAndPolicies().then((_) {
        if (mounted && provider.myLeavePolicies.isNotEmpty && _selectedPolicyId == null) {
          setState(() {
            _selectedPolicyId = provider.myLeavePolicies.first['lp_id'];
          });
        }
      });
      final auth = context.read<AuthService>();
      if (auth.user?.isAdmin == true) {
        provider.fetchStaffAssignmentData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staffSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final isAdmin = authService.user?.isAdmin ?? false;
    final provider = context.watch<LeaveProvider>();
    final policies = provider.myLeavePolicies;
    final isLoading = provider.isLoadingBalances;

    final query = _searchController.text.trim().toLowerCase();
    final filteredPolicies = policies.where((p) {
      final name = (p['name']?.toString() ?? '').toLowerCase();
      final desc = (p['description']?.toString() ?? '').toLowerCase();
      return query.isEmpty || name.contains(query) || desc.contains(query);
    }).toList();

    final selectedPolicy = policies.firstWhere(
      (p) => p['lp_id'] == _selectedPolicyId,
      orElse: () => policies.isNotEmpty ? policies.first : {},
    );

    final rules = (selectedPolicy['rules'] as List<dynamic>?) ?? [];

    final classification = provider.getStaffClassification(
      selectedPolicy['lp_id'],
      queryOverride: _staffSearchController.text,
    );
    final assignedStaff = (classification['assigned'] as List<Map<String, dynamic>>?) ?? [];
    final availableStaff = (classification['available'] as List<Employee>?) ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Policy Search
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search policies...',
                      hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  provider.fetchMyLeaveBalancesAndPolicies(forceRefresh: true);
                  if (isAdmin) {
                    provider.fetchStaffAssignmentData(forceRefresh: true);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF6366F1),
                tooltip: 'Refresh',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Policy Choice Chips
          if (filteredPolicies.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredPolicies.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final p = filteredPolicies[idx];
                  final isSelected = p['lp_id'] == selectedPolicy['lp_id'];
                  return ChoiceChip(
                    label: Text(p['name']?.toString() ?? 'Policy'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedPolicyId = p['lp_id'];
                      });
                    },
                    selectedColor: const Color(0xFF4F46E5),
                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Admin Sub-Tab Switcher: "Policy Rules" vs "Staff Assignment"
          if (isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubTabToggle(
                      label: 'Policy Rules',
                      icon: Icons.rule_folder_outlined,
                      index: 0,
                      count: rules.length,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildSubTabToggle(
                      label: 'Staff Assignment',
                      icon: Icons.people_outline_rounded,
                      index: 1,
                      count: assignedStaff.length,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

          // Content Area
          Expanded(
            child: isLoading && policies.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : policies.isEmpty
                    ? Center(
                        child: Text(
                          'No policies found.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      )
                    : (_activeSubTab == 1 && isAdmin)
                        ? _buildStaffAssignmentView(
                            context: context,
                            selectedPolicy: selectedPolicy,
                            assignedStaff: assignedStaff,
                            availableStaff: availableStaff,
                            provider: provider,
                            isDark: isDark,
                          )
                        : _buildPolicyRulesView(
                            selectedPolicy: selectedPolicy,
                            rules: rules,
                            isDark: isDark,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabToggle({
    required String label,
    required IconData icon,
    required int index,
    required int count,
    required bool isDark,
  }) {
    final isSelected = _activeSubTab == index;
    return InkWell(
      onTap: () => setState(() => _activeSubTab = index),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF21262D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? Colors.white54 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // VIEW 1: POLICY RULES
  // ==========================================================================

  Widget _buildPolicyRulesView({
    required Map<String, dynamic> selectedPolicy,
    required List<dynamic> rules,
    required bool isDark,
  }) {
    return ListView(
      children: [
        // Policy Description Card
        if (selectedPolicy.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text(
                      selectedPolicy['name']?.toString() ?? 'Policy',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (selectedPolicy['description'] != null &&
                    selectedPolicy['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    selectedPolicy['description'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Policy Rules Heading
        Text(
          'Policy Rules (${rules.length})',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        if (rules.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'No rules configured for this policy.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...rules.map((rule) {
            final name = rule['name']?.toString() ?? 'Rule';
            final code = rule['code']?.toString() ?? 'R';
            final maxBalance = rule['max_balance']?.toString() ?? '12';
            final accrual = rule['accural_type']?.toString() ?? 'No Accrual';
            final isPaid = rule['is_paid'] == 1 || rule['is_paid'] == true;
            final requiresDoc = rule['requires_doc'] == 1 || rule['requires_doc'] == true;
            final carryForward = rule['carry_forward'] == 1 || rule['carry_forward'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                              : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E8)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Unpaid',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildTag('Max: $maxBalance days', isDark),
                      _buildTag(accrual, isDark),
                      if (carryForward) _buildTag('Carry Forward Enabled', isDark),
                      if (requiresDoc) _buildTag('Doc Required', isDark, isWarning: true),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // VIEW 2: STAFF ASSIGNMENT (MATCHING WEB PolicyStaffAssignment.jsx)
  // ==========================================================================

  Widget _buildStaffAssignmentView({
    required BuildContext context,
    required Map<String, dynamic> selectedPolicy,
    required List<Map<String, dynamic>> assignedStaff,
    required List<Employee> availableStaff,
    required LeaveProvider provider,
    required bool isDark,
  }) {
    final policyName = selectedPolicy['name']?.toString() ?? 'Selected Policy';
    final policyId = selectedPolicy['lp_id'] as int?;

    return ListView(
      children: [
        // Year Selector & Staff Search
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        'Target Year',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),

                  // Year Dropdown
                  SizedBox(
                    width: 115,
                    child: AppCustomDropdown<int>(
                      hintText: 'Year',
                      initialValue: provider.staffAssignmentYear,
                      isDense: true,
                      prefixIcon: Icons.calendar_today_rounded,
                      items: List.generate(5, (i) {
                        final y = DateTime.now().year - 2 + i;
                        return AppDropdownItem<int>(
                          value: y,
                          label: y.toString(),
                          icon: Icons.event_rounded,
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          provider.setStaffAssignmentYear(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Search staff
              SizedBox(
                height: 36,
                child: TextField(
                  controller: _staffSearchController,
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or email...',
                    hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    suffixIcon: _staffSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 14),
                            onPressed: () {
                              _staffSearchController.clear();
                              setState(() {});
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // SECTION 1: Assigned Staff
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned Staff (${assignedStaff.length})',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6366F1),
              ),
            ),
            if (provider.isLoadingStaffAssignment)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (assignedStaff.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Text(
                'No assigned staff matching current filters.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
          )
        else
          ...assignedStaff.map((item) {
            final emp = item['employee'] as Employee;
            final balances = (item['balances'] as List<dynamic>?) ?? [];
            final balanceIds = balances
                .map((b) => int.tryParse(b['lb_id']?.toString() ?? '0'))
                .whereType<int>()
                .where((id) => id > 0)
                .toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(emp, isDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    emp.userName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (emp.designation != null && emp.designation!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      emp.designation!,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              emp.email,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Unassign Button
                      IconButton(
                        icon: const Icon(Icons.person_remove_outlined, size: 18),
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        tooltip: 'Unassign Policy',
                        onPressed: () async {
                          final confirm = await CustomDialog.show(
                            context: context,
                            title: 'Unassign Policy?',
                            message:
                                'Are you sure you want to unassign "${emp.userName}" from "$policyName"? This will delete all their leave balances under this policy for year ${provider.staffAssignmentYear}.',
                            positiveButtonText: 'Unassign',
                            isDestructive: true,
                            onPositivePressed: () {},
                          );

                          if (confirm == true && context.mounted) {
                            try {
                              await provider.unassignPolicyFromStaff(
                                userId: emp.userId,
                                balanceIds: balanceIds,
                                year: provider.staffAssignmentYear,
                              );
                              if (context.mounted) {
                                context.showToast('Policy unassigned from ${emp.userName}', isSuccess: true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                context.showToast('Failed to unassign policy: $e', isSuccess: false);
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),

                  // Rule balances breakdown
                  if (balances.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: balances.map((bal) {
                          final type = bal['leave_type']?.toString() ?? 'Leave';
                          final avail = bal['available']?.toString() ?? '0';
                          final alloc = bal['allocated']?.toString() ?? '0';
                          final lbId = int.tryParse(bal['lb_id']?.toString() ?? '0');
                          final carriedForward = double.tryParse(bal['carried_forward']?.toString() ?? '0') ?? 0;
                          final used = double.tryParse(bal['used']?.toString() ?? '0') ?? 0;
                          final allocatedNum = double.tryParse(alloc) ?? 0;

                          return InkWell(
                            onTap: lbId != null && lbId > 0
                                ? () {
                                    final auth = context.read<AuthService>();
                                    final leaveService = LeaveService(auth.dio);
                                    AdjustBalanceDialog.show(
                                      context,
                                      balanceId: lbId,
                                      employeeName: emp.userName,
                                      leaveType: type,
                                      initialAllocated: allocatedNum,
                                      initialCarriedForward: carriedForward,
                                      initialUsed: used,
                                      leaveService: leaveService,
                                      onSaved: () {
                                        provider.fetchStaffAssignmentData(forceRefresh: true);
                                      },
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$type: ',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    '$avail/$alloc d',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 11,
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

        const SizedBox(height: 16),

        // SECTION 2: Available Staff
        Text(
          'Available Staff (${availableStaff.length})',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),

        if (availableStaff.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Text(
                'All staff members have this policy assigned.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
          )
        else
          ...availableStaff.map((emp) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildAvatar(emp, isDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                emp.userName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (emp.designation != null && emp.designation!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${emp.designation!}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emp.email,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Assign Button
                  ElevatedButton.icon(
                    onPressed: policyId == null
                        ? null
                        : () async {
                            try {
                              final ok = await provider.assignPolicyToStaff(
                                policyId: policyId,
                                userId: emp.userId,
                                year: provider.staffAssignmentYear,
                              );
                              if (ok && context.mounted) {
                                context.showToast('Policy assigned to ${emp.userName}', isSuccess: true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                context.showToast('Failed to assign policy: $e', isSuccess: false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 15),
                    label: Text(
                      'Assign',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAvatar(Employee emp, bool isDark) {
    if (emp.profileImage != null && emp.profileImage!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          emp.profileImage!,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildInitialsAvatar(emp, isDark),
        ),
      );
    }
    return _buildInitialsAvatar(emp, isDark);
  }

  Widget _buildInitialsAvatar(Employee emp, bool isDark) {
    final initial = emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : 'U';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, bool isDark, {bool isWarning = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isWarning
              ? const Color(0xFFF59E0B)
              : (isDark ? Colors.white60 : Colors.grey.shade700),
        ),
      ),
    );
  }
}
