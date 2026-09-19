import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/core/leave_provider.dart';
import 'package:flutter_application/features/leave/core/leave_request_model.dart';
import 'package:flutter_application/features/leave/widgets/employee_leave_plan_card.dart';
import 'package:flutter_application/features/leave/widgets/leave_history_item.dart';
import 'package:flutter_application/features/leave/widgets/apply_leave_sheet.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_list_item.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_detail_view.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';

class LeaveMobileView extends StatefulWidget {
  const LeaveMobileView({super.key});

  @override
  State<LeaveMobileView> createState() => _LeaveMobileViewState();
}

class _LeaveMobileViewState extends State<LeaveMobileView> {
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: isAdmin ? _buildAdminView(context, isDark) : _buildEmployeeView(context, isDark),
      ),
    );
  }

  // ==========================================================================
  // ADMIN VIEW
  // ==========================================================================

  Widget _buildAdminView(BuildContext context, bool isDark) {
    final provider = context.watch<LeaveProvider>();
    final filtered = provider.adminFilteredLeaves;
    final isLoading = provider.isLoadingAdminHistory;

    final filterOptions = [
      {'id': 'all', 'label': 'All'},
      {'id': 'pending', 'label': 'Pending'},
      {'id': 'approved', 'label': 'Approved'},
      {'id': 'rejected', 'label': 'Rejected'},
    ];

    return Column(
      children: [
        // Search Bar & Apply Leave Button
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
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
                      hintText: 'Search leave...',
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
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => ApplyLeaveSheet.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: Text(
                    'Apply Leave',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Status Filter Chips
        SizedBox(
          height: 32,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
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
                        : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Requests List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.fetchAdminHistory(forceRefresh: true),
            child: isLoading && provider.adminHistory.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No leave requests found.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
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
  // EMPLOYEE VIEW
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
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Bar Card
            Container(
              margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              padding: const EdgeInsets.all(12),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${filteredLeaves.length} Requests',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${provider.totalApprovedDays} Days Approved',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      ElevatedButton.icon(
                        onPressed: () => ApplyLeaveSheet.show(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Month & Year Filter Selectors
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

                      const SizedBox(width: 8),

                      // Year Selector
                      SizedBox(
                        width: 100,
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
                    ],
                  ),
                ],
              ),
            ),

            // SECTION 1: Leave Plan & Balances
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'My Leave Plan & Balances',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Year ${provider.selectedYear}',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            if (balances.isEmpty && policies.isEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        'No leave plan assigned yet',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact your HR team to get a leave policy assigned.',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Policy Name & Description Header Badge (Matching Web)
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
                                child: const Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Color(0xFF6366F1),
                                ),
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

                    // Plan Rule Cards
                    ...List.generate(
                      balances.isNotEmpty ? balances.length : 1,
                      (idx) {
                        final bal = balances.isNotEmpty ? balances[idx] : null;
                        final rule = {
                          'name': bal?['leave_type'] ?? 'General Leave',
                          'code': bal?['leave_code'] ?? 'GL',
                          'accural_type': 'Standard Accrual',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: EmployeeLeavePlanCard(
                            rule: rule,
                            balance: bal,
                            index: idx,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // SECTION 2: My Leave Requests
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Leave Requests',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),

            if (isLoading && provider.myLeaves.isEmpty) ...[
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )),
            ] else if (filteredLeaves.isEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No requests this month',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No leave requests found for ${monthNames[provider.selectedMonth]} ${provider.selectedYear}.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
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
