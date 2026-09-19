import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/features/leave/widgets/employee_leave_plan_card.dart';
import 'package:flutter_application/features/leave/widgets/leave_history_item.dart';
import 'package:flutter_application/features/leave/widgets/apply_leave_sheet.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_list_item.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_detail_view.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class LeaveTabletLandscape extends StatefulWidget {
  const LeaveTabletLandscape({super.key});

  @override
  State<LeaveTabletLandscape> createState() => _LeaveTabletLandscapeState();
}

class _LeaveTabletLandscapeState extends State<LeaveTabletLandscape> {
  final _searchController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAdmin = authService.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: isAdmin ? _buildAdminSplitView(context, isDark) : _buildEmployeeView(context, isDark),
      ),
    );
  }

  // ==========================================================================
  // ADMIN SPLIT VIEW - EXACT REPLICA OF WEB AdminLeaveRequests.jsx
  // ==========================================================================

  Widget _buildAdminSplitView(BuildContext context, bool isDark) {
    final provider = context.watch<LeaveProvider>();
    final filtered = provider.adminFilteredLeaves;
    final selectedLeave = provider.selectedAdminLeave;
    final isLoading = provider.isLoadingAdminHistory;

    final filterOptions = [
      {'id': 'all', 'label': 'All'},
      {'id': 'pending', 'label': 'Pending'},
      {'id': 'approved', 'label': 'Approved'},
      {'id': 'rejected', 'label': 'Rejected'},
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT PANEL (flex: 38): Search, Filter & List
        Expanded(
          flex: 38,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              children: [
                // Search & Filter Header (No Card Background)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => provider.setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Search by employee name...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _searchController.clear();
                                        provider.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => ApplyLeaveSheet.show(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            'Apply Leave',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 10),
                      // Horizontal Filter Chips
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filterOptions.length,
                          separatorBuilder: (_, index) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final opt = filterOptions[index];
                            final isSelected = provider.statusFilter == opt['id'];

                            return ChoiceChip(
                              label: Text(opt['label']!),
                              selected: isSelected,
                              onSelected: (_) => provider.setStatusFilter(opt['id']!),
                              selectedColor: const Color(0xFF4F46E5),
                              backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              labelStyle: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                                ),
                              ),
                              showCheckmark: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // List
                Expanded(
                  child: isLoading && provider.adminHistory.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No requests found.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final req = filtered[index];
                                final isSelected = selectedLeave?.id == req.id;
                                return AdminLeaveListItem(
                                  request: req,
                                  isSelected: isSelected,
                                  onTap: () => provider.selectAdminLeave(req),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),

        // RIGHT PANEL (flex: 62): Full Details & Review Action Card
        Expanded(
          flex: 62,
          child: Container(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            child: AdminLeaveDetailView(
              request: selectedLeave,
              onStatusUpdated: () {
                provider.fetchAdminHistory(forceRefresh: true);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // EMPLOYEE VIEW - TABLET LANDSCAPE DASHBOARD
  // ==========================================================================

  Widget _buildEmployeeView(BuildContext context, bool isDark) {
    final provider = context.watch<LeaveProvider>();
    final filteredLeaves = provider.filteredMyLeaves;
    final balances = provider.myLeaveBalances;
    final policies = provider.myLeavePolicies;
    final isLoading = provider.isLoadingMyLeaves;

    final monthNames = List.generate(
      12,
      (i) => DateFormat('MMMM').format(DateTime(2026, i + 1)),
    );

    return RefreshIndicator(
      onRefresh: () => provider.fetchLeaves(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Leave',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${filteredLeaves.length} Requests',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${provider.totalApprovedDays} Days Approved',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      // Month Selector
                      Expanded(
                        child: AppCustomDropdown<int>(
                          hintText: 'Month',
                          initialValue: provider.selectedMonth,
                          isDense: true,
                          prefixIcon: Icons.calendar_month_outlined,
                          items: List.generate(12, (idx) {
                            return AppDropdownItem<int>(
                              value: idx,
                              label: monthNames[idx],
                              icon: Icons.calendar_today_rounded,
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) provider.setSelectedMonth(val);
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Year Selector
                      SizedBox(
                        width: 120,
                        child: AppCustomDropdown<int>(
                          hintText: 'Year',
                          initialValue: provider.selectedYear,
                          isDense: true,
                          prefixIcon: Icons.calendar_today_rounded,
                          items: List.generate(5, (idx) {
                            final yr = DateTime.now().year - 2 + idx;
                            return AppDropdownItem<int>(
                              value: yr,
                              label: yr.toString(),
                              icon: Icons.event_rounded,
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) provider.setSelectedYear(val);
                          },
                        ),
                      ),

                      const SizedBox(width: 16),

                      ElevatedButton.icon(
                        onPressed: () => ApplyLeaveSheet.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Apply for Leave',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // SECTION 1: Leave Plan & Balances in 3-Column Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'My Leave Plan & Balances',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Calendar Year ${provider.selectedYear}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            if (balances.isEmpty && policies.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 42, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'No leave plan assigned yet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact your HR team to get a leave policy assigned.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              if (policies.isNotEmpty) ...[
                ...policies.where((p) => p['is_active'] != false).map((pol) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pol['name']?.toString() ?? 'Leave Policy',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (pol['description'] != null && pol['description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  pol['description'].toString(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.2,
                ),
                itemCount: balances.length,
                itemBuilder: (context, idx) {
                  final bal = balances[idx];
                  final rule = {
                    'name': bal['leave_type'] ?? 'General Leave',
                    'code': bal['leave_code'] ?? 'GL',
                    'accural_type': 'Standard Accrual',
                  };
                  return EmployeeLeavePlanCard(
                    rule: rule,
                    balance: bal,
                    index: idx,
                  );
                },
              ),
            ],

            const SizedBox(height: 28),

            // SECTION 2: My Leave Requests
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Leave Requests',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            if (isLoading && provider.myLeaves.isEmpty) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
            ] else if (filteredLeaves.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No requests this month',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No leave requests found for ${monthNames[provider.selectedMonth]} ${provider.selectedYear}.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ...filteredLeaves.map((leave) {
                return LeaveHistoryItem(
                  request: leave,
                  onDelete: leave.status == 'pending'
                      ? () async {
                          final confirm = await CustomDialog.show(
                            context: context,
                            title: 'Withdraw Request?',
                            message: 'Are you sure you want to withdraw this leave request?',
                            positiveButtonText: 'Withdraw',
                            onPositivePressed: () {},
                            isDestructive: true,
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<LeaveProvider>().withdrawRequest(leave.id);
                            if (context.mounted) {
                              context.showToast('Request withdrawn successfully.', isSuccess: true);
                            }
                          }
                        }
                      : null,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
