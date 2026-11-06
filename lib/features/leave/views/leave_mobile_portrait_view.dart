import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/widgets/employee_leave_plan_card.dart';
import 'package:flutter_application/features/leave/widgets/apply_leave_sheet.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_list_item.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_detail_view.dart';
import 'package:flutter_application/features/leave/widgets/leave_policies_tab.dart';
import 'package:flutter_application/features/leave/widgets/employee_leave_detail_sheet.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class LeaveMobileView extends StatefulWidget {
  const LeaveMobileView({super.key});

  @override
  State<LeaveMobileView> createState() => _LeaveMobileViewState();
}

class _LeaveMobileViewState extends State<LeaveMobileView> {
  final _searchController = TextEditingController();
  final _mySearchController = TextEditingController();
  bool _isPlanCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LeaveProvider>().fetchLeaves();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mySearchController.dispose();
    super.dispose();
  }

  void _showPoliciesBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.policy_outlined, size: 16, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Leave Policies & Rules',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
            const Expanded(child: LeavePoliciesTab()),
          ],
        ),
      ),
    );
  }

  void _showAdminReviewSheet(LeaveRequest request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: AdminLeaveDetailView(
                  request: request,
                  onStatusUpdated: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAdmin = authService.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: isAdmin ? _buildAdminView(context, isDark) : _buildEmployeeView(context, isDark),
    );
  }

  // ==========================================================================
  // ADMIN VIEW (Single Main Tab, tight compact spacing)
  // ==========================================================================

  Widget _buildAdminView(BuildContext context, bool isDark) {
    final provider = context.watch<LeaveProvider>();
    final filtered = provider.adminFilteredLeaves;
    final isLoading = provider.isLoadingAdminHistory;
    final adminCounts = provider.adminLeaveCounts;

    final filterOptions = [
      {'id': 'all', 'label': 'All (${adminCounts['all'] ?? 0})'},
      {'id': 'pending', 'label': 'Pending (${adminCounts['pending'] ?? 0})'},
      {'id': 'approved', 'label': 'Approved (${adminCounts['approved'] ?? 0})'},
      {'id': 'rejected', 'label': 'Rejected (${adminCounts['rejected'] ?? 0})'},
    ];

    return Column(
      children: [
        // Search Bar & Action Buttons (Tightened & directly below main tab bar)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => provider.setSearchQuery(val),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search staff, leave type, reason...',
                      hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
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
              const SizedBox(width: 6),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  padding: EdgeInsets.zero,
                  onPressed: () => provider.fetchAdminHistory(forceRefresh: true),
                  tooltip: 'Refresh',
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.policy_outlined, size: 16),
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  padding: EdgeInsets.zero,
                  onPressed: () => _showPoliciesBottomSheet(context, isDark),
                  tooltip: 'Leave Policies',
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => ApplyLeaveSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text(
                    'Apply',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Status Filter Chips
        SizedBox(
          height: 30,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: filterOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              final opt = filterOptions[index];
              final isSelected = provider.statusFilter == opt['id'];

              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                onSelected: (_) => provider.setStatusFilter(opt['id']!),
                selectedColor: const Color(0xFF4F46E5),
                backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                labelStyle: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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

        const SizedBox(height: 6),

        // Requests List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.fetchAdminHistory(forceRefresh: true),
            color: const Color(0xFF6366F1),
            child: isLoading && provider.adminHistory.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 40,
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              provider.searchQuery.isNotEmpty
                                  ? 'No requests matching "${provider.searchQuery}"'
                                  : 'No ${provider.statusFilter} leave requests',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          return AdminLeaveListItem(
                            request: req,
                            isSelected: false,
                            onTap: () {
                              provider.selectAdminLeave(req);
                              _showAdminReviewSheet(req);
                            },
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // EMPLOYEE VIEW - Matches web LeaveApplication.jsx employee layout
  // ==========================================================================

  Widget _buildEmployeeView(BuildContext context, bool isDark) {
    final provider = context.watch<LeaveProvider>();
    final myFilteredLeaves = provider.myFilteredLeaves;
    final counts = provider.myLeaveCounts;
    final balances = provider.myLeaveBalances;
    final policies = provider.myLeavePolicies;
    final isLoading = provider.isLoadingMyLeaves;

    final statusTabs = [
      {'id': 'all', 'label': 'All'},
      {'id': 'pending', 'label': 'Pending'},
      {'id': 'approved', 'label': 'Approved'},
      {'id': 'rejected', 'label': 'Rejected'},
    ];

    final monthNames = List.generate(12, (i) => DateFormat('MMMM').format(DateTime(2026, i + 1)));

    return RefreshIndicator(
      onRefresh: () => provider.fetchLeaves(forceRefresh: true),
      color: const Color(0xFF6366F1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ TOP ACTION BAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Leave',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildCountBadge(
                              '${counts['all']} Total',
                              isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                              isDark ? Colors.white60 : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 5),
                            _buildCountBadge(
                              '${provider.totalApprovedDays} Days Approved',
                              const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
                              const Color(0xFF6366F1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ApplyLeaveSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: Text(
                      'Apply',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Month / Year filter (for the totalApprovedDays summary only)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppCustomDropdown<int>(
                      hintText: 'Month',
                      initialValue: provider.selectedMonth,
                      isDense: true,
                      prefixIcon: Icons.calendar_month_outlined,
                      items: List.generate(12, (idx) => AppDropdownItem<int>(
                        value: idx,
                        label: monthNames[idx],
                        icon: Icons.calendar_today_rounded,
                      )),
                      onChanged: (val) { if (val != null) provider.setSelectedMonth(val); },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: AppCustomDropdown<int>(
                      hintText: 'Year',
                      initialValue: provider.selectedYear,
                      isDense: true,
                      prefixIcon: Icons.calendar_today_rounded,
                      items: List.generate(5, (idx) {
                        final yr = DateTime.now().year - 2 + idx;
                        return AppDropdownItem<int>(value: yr, label: yr.toString(), icon: Icons.event_rounded);
                      }),
                      onChanged: (val) { if (val != null) provider.setSelectedYear(val); },
                    ),
                  ),
                ],
              ),
            ),

            // â”€â”€ SECTION 1: LEAVE PLAN & BALANCES â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            _buildSectionHeader(
              'My Leave Plan & Balances',
              'Year ${provider.selectedYear}',
              isDark,
              isCollapsible: true,
              isCollapsed: _isPlanCollapsed,
              onToggle: () => setState(() => _isPlanCollapsed = !_isPlanCollapsed),
            ),

            if (!_isPlanCollapsed) ...[
              if (balances.isEmpty && policies.isEmpty) ...[
              _buildEmptyCard(
                Icons.shield_outlined,
                'No leave plan assigned yet',
                'Contact your HR team to get a leave policy assigned.',
                isDark,
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (policies.isNotEmpty) ...[
                      ...policies.where((p) => p['is_active'] != false).map((pol) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF6366F1)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pol['name']?.toString() ?? 'Leave Policy',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (pol['description'] != null && pol['description'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        pol['description'].toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    ...List.generate(balances.length, (idx) {
                      final bal = balances[idx];
                      final rule = {
                        'name': bal['leave_type'] ?? 'General Leave',
                        'code': bal['leave_code'] ?? bal['code'] ?? 'GL',
                        'accural_type': bal['accural_type'] ?? '',
                        'max_balance': bal['max_balance'],
                        'is_paid': bal['is_paid'],
                        'carry_forward': bal['carry_forward'],
                        'encashable': bal['encashable'],
                        'requires_doc': bal['requires_doc'],
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: EmployeeLeavePlanCard(rule: rule, balance: bal, index: idx),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],

            const SizedBox(height: 16),

            // â”€â”€ SECTION 2: REQUESTS QUEUE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Queue header
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0D1117).withValues(alpha: 0.5)
                          : const Color(0xFFF8FAFC).withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Requests Queue',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF21262D) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '${myFilteredLeaves.length} ${myFilteredLeaves.length == 1 ? 'request' : 'requests'}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6366F1)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Search field & Refresh button
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 34,
                                child: TextField(
                                  controller: _mySearchController,
                                  onChanged: (val) => context.read<LeaveProvider>().setMySearchQuery(val),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Search leave...',
                                    hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Colors.grey),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    suffixIcon: provider.mySearchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 14),
                                            onPressed: () {
                                              _mySearchController.clear();
                                              context.read<LeaveProvider>().setMySearchQuery('');
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 28),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                                    ),
                                  ),
                                  style: GoogleFonts.inter(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              height: 34,
                              width: 34,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.refresh_rounded, size: 15),
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                padding: EdgeInsets.zero,
                                onPressed: () => context.read<LeaveProvider>().fetchLeaves(forceRefresh: true),
                                tooltip: 'Refresh',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Status filter tabs
                        Row(
                          children: statusTabs.map((tab) {
                            final id = tab['id']!;
                            final label = tab['label']!;
                            final count = counts[id] ?? 0;
                            final isSelected = provider.myStatusFilter == id;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => context.read<LeaveProvider>().setMyStatusFilter(id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isSelected
                                        ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35))
                                        : null,
                                  ),
                                  child: Text(
                                    count > 0 ? '$label ($count)' : label,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF6366F1)
                                          : (isDark ? Colors.white54 : Colors.grey.shade600),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                  ),

                  // Leave items
                  if (myFilteredLeaves.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 36, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text(
                              'No requests found.',
                              style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white38 : Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: myFilteredLeaves.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final leave = entry.value;
                        return Column(
                          children: [
                            if (idx > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                indent: 14,
                                endIndent: 14,
                              ),
                            _buildLeaveQueueItem(context, leave, isDark),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveQueueItem(BuildContext context, leave, bool isDark) {
    final status = (leave.status as String).toLowerCase();
    final Color statusColor;
    final Color statusBg;
    if (status == 'approved') {
      statusColor = const Color(0xFF10B981);
      statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFEF4444);
      statusBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusBg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    }
    final dateFormat = DateFormat('d MMM yyyy');

    return InkWell(
      onTap: () {
        EmployeeLeaveDetailSheet.show(
          context,
          leave,
          onWithdrawn: () => context.read<LeaveProvider>().fetchLeaves(forceRefresh: true),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          leave.policyName ?? leave.leaveType ?? 'Leave',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${dateFormat.format(leave.startDate)} â€“ ${dateFormat.format(leave.endDate)}',
                    style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${leave.durationDays} Day${leave.durationDays > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                      ),
                      if (leave.reason.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Text('Â·', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            leave.reason,
                            style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String? trailing,
    bool isDark, {
    bool isCollapsible = false,
    bool isCollapsed = false,
    VoidCallback? onToggle,
  }) {
    return InkWell(
      onTap: isCollapsible ? onToggle : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing,
                style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ],
            if (isCollapsible) ...[
              if (trailing == null) const Spacer(),
              const SizedBox(width: 6),
              Icon(
                isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildEmptyCard(IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
