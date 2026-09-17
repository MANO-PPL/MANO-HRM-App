import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_audit_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/features/payroll/core/payslip_pdf_service.dart';
import 'package:flutter_application/features/payroll/widgets/pay_period_selector.dart';
import 'package:flutter_application/features/payroll/widgets/payroll_metric_badge.dart';
import 'package:flutter_application/features/payroll/widgets/payslip_detail_mobile_portrait_view.dart';

class PayrollScreenMobile extends StatefulWidget {
  const PayrollScreenMobile({super.key});

  @override
  State<PayrollScreenMobile> createState() => _PayrollScreenMobileState();
}

class _PayrollScreenMobileState extends State<PayrollScreenMobile>
    with SingleTickerProviderStateMixin {
  late PayrollService _payrollService;
  late TabController _tabController;

  // --- Payroll Run tab state ---
  bool _isLoading = true;
  PayrollRun? _payrollRun;
  List<Payslip> _payslips = [];
  List<Payslip> _allPayslips = [];
  String _selectedPeriod = '';
  String _selectedDept = 'All';
  final TextEditingController _searchController = TextEditingController();

  // departments are loaded from data to avoid hardcoding
  List<String> _departments = ['All'];

  // --- Lock state ---
  String? _lockingId; // employeeId being toggled

  // --- Audit Trail tab state ---
  bool _isLoadingAudit = false;
  List<PayrollAuditLog> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    final authService = Provider.of<AuthService>(context, listen: false);
    _payrollService = PayrollService(authService.dio);
    _selectedPeriod = _payrollService.currentPayPeriod;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_isLoadingAudit) {
      _loadAuditLogs();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data Loading
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _payrollService.getPayrollDashboard(payPeriod: _selectedPeriod);
      if (mounted) {
        // Build department list from real data
        final depts = <String>{'All'};
        for (final s in result.payslips) {
          if (s.department.isNotEmpty) depts.add(s.department);
        }
        setState(() {
          _payrollRun = result.run;
          _allPayslips = result.payslips;
          _payslips = _applyFilters(result.payslips);
          _departments = depts.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading payroll mobile data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAudit = true);
    try {
      final logs = await _payrollService.getAuditLogs(payPeriod: _selectedPeriod);
      if (mounted) setState(() => _auditLogs = logs);
    } catch (e) {
      debugPrint('Error loading audit logs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAudit = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filtering
  // ─────────────────────────────────────────────────────────────────────────

  List<Payslip> _applyFilters(List<Payslip> source) {
    final q = _searchController.text.trim().toLowerCase();
    return source.where((slip) {
      final matchesDept = _selectedDept == 'All' ||
          slip.department.toLowerCase() == _selectedDept.toLowerCase();
      final matchesSearch = q.isEmpty ||
          slip.employeeName.toLowerCase().contains(q) ||
          slip.employeeId.toLowerCase().contains(q) ||
          slip.designation.toLowerCase().contains(q);
      return matchesDept && matchesSearch;
    }).toList();
  }

  void _onSearchChanged(String _) =>
      setState(() => _payslips = _applyFilters(_allPayslips));

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      _auditLogs = []; // reset audit logs for the new period
    });
    _loadData();
    if (_tabController.index == 1) _loadAuditLogs();
  }

  void _onDeptChanged(String dept) {
    setState(() {
      _selectedDept = dept;
      _payslips = _applyFilters(_allPayslips);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _openPayslipDetail(Payslip slip) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isEmployee = authService.user?.isEmployee ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PayslipDetailScreenMobile(
        payslip: slip,
        payrollService: _payrollService,
        isAdmin: !isEmployee,
        onStatusChanged: () async {
          await _loadData();
          await _loadAuditLogs();
        },
      ),
    );
  }

  Future<void> _toggleLock(Payslip slip, bool isAdmin) async {
    if (!isAdmin) return;
    final isLocked = slip.status.isLocked;

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(
                isLocked ? Icons.lock_open_outlined : Icons.lock_outlined,
                color: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isLocked ? 'Unlock Payroll?' : 'Lock & Finalize?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            isLocked
                ? 'This will revert ${slip.employeeName}\'s payroll back to Draft status.'
                : 'This will finalize and lock ${slip.employeeName}\'s payroll for ${slip.payPeriod}.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isLocked ? 'Unlock' : 'Lock',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _lockingId = slip.employeeId);
    try {
      if (isLocked) {
        await _payrollService.unlockEmployee(
          employeeId: slip.employeeId,
          payPeriod: _selectedPeriod,
          employeeName: slip.employeeName,
        );
        if (mounted) {
          context.showToast(
            "${slip.employeeName}'s payroll unlocked.",
            isWarning: true,
          );
        }
      } else {
        await _payrollService.finalizeEmployee(
          employeeId: slip.employeeId,
          payPeriod: _selectedPeriod,
          employeeName: slip.employeeName,
        );
        if (mounted) {
          context.showToast(
            "${slip.employeeName}'s payroll locked & finalized.",
            isSuccess: true,
          );
        }
      }
      await _loadData();
      await _loadAuditLogs();
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: 'Action failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _lockingId = null);
    }
  }

  Future<void> _downloadPdf(Payslip slip) async {
    try {
      final path = await PayslipPdfService.generateAndSavePayslipPdf(slip);
      if (mounted) {
        context.showToast(
          'PDF saved: ${path.split('/').last}',
          isSuccess: true,
          actionLabel: 'OPEN',
          onActionPressed: () => PayslipPdfService.openPayslipPdf(path),
        );
        await PayslipPdfService.openPayslipPdf(path);
      }
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: 'Failed to generate PDF');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isEmployee = authService.user?.isEmployee ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockedCount = _allPayslips.where((s) => s.status.isLocked).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Pill Styled Full Width Tab Bar (Matching DAR) ───────────
          Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.receipt_long_outlined, size: 15),
                      SizedBox(width: 5),
                      Text("Salary Slips"),
                    ],
                  ),
                ),
                Tab(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 15),
                      const SizedBox(width: 5),
                      const Text("Audit Trail"),
                      if (_auditLogs.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B60F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_auditLogs.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPayrollTab(isDark, isEmployee, lockedCount),
                _buildAuditTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 1: Salary Slips
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPayrollTab(bool isDark, bool isEmployee, int lockedCount) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pay Period Selector (no Run Payroll button)
            PayPeriodSelector(
              selectedPeriod: _selectedPeriod,
              availablePeriods: _payrollService.availablePayPeriods,
              onPeriodChanged: _onPeriodChanged,
              status: _payrollRun?.status ?? PayrollStatus.draft,
              onProcessTap: null, // Run Payroll removed
              isCompact: true,
            ),

            const SizedBox(height: 8),

            // Lock progress indicator (admin only)
            if (!isEmployee && _allPayslips.isNotEmpty)
              _buildLockProgressBadge(lockedCount, _allPayslips.length, isDark),

            const SizedBox(height: 8),

            // Summary Metric Cards
            if (_payrollRun != null) ...[
              Row(
                children: [
                  Expanded(
                    child: PayrollMetricBadge(
                      title: 'Total Net Payout',
                      value: _payrollRun!.formattedTotalNet,
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF6366F1),
                      subtitle: '${_payrollRun!.totalEmployees} Staff Processed',
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: PayrollMetricBadge(
                      title: 'Gross Earnings',
                      value: _payrollRun!.formattedTotalGross,
                      icon: Icons.account_balance_outlined,
                      color: const Color(0xFF10B981),
                      subtitle: 'Before Deductions',
                      isCompact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: PayrollMetricBadge(
                      title: 'Total Deductions',
                      value: _payrollRun!.formattedTotalDeductions,
                      icon: Icons.remove_circle_outline,
                      color: const Color(0xFFEF4444),
                      subtitle: 'LOP + OT Adj.',
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: PayrollMetricBadge(
                      title: 'Pay Run Status',
                      value: _payrollRun!.status.label,
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF8B5CF6),
                      subtitle: _payrollRun!.isLocked ? 'Period Locked' : 'In Progress',
                      isCompact: true,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Search Bar
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search employee or ID...',
                  hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26),
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Department Filter Chips (dynamic from data)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _departments.map((dept) {
                  final isSelected = _selectedDept == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _onDeptChanged(dept),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4338CA)
                              : (isDark ? const Color(0xFF161B22) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4338CA)
                                : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          dept,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SALARY SLIPS (${_payslips.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                if (!_isLoading && _allPayslips.isNotEmpty)
                  Text(
                    _selectedPeriod,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Payslip Cards / States
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_payslips.isEmpty)
              _buildEmptyState(isDark)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payslips.length,
                itemBuilder: (context, index) =>
                    _buildPayslipCard(_payslips[index], isDark, isEmployee),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab 2: Audit Trail
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAuditTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAuditLogs,
      child: Column(
        children: [
          // Period + refresh header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                const Icon(Icons.history, size: 14, color: Color(0xFF4338CA)),
                const SizedBox(width: 6),
                Text(
                  'Audit Trail — $_selectedPeriod',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _loadAuditLogs,
                  child: const Icon(Icons.refresh, size: 16, color: Color(0xFF4338CA)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoadingAudit
                ? const Center(child: CircularProgressIndicator())
                : _auditLogs.isEmpty
                    ? _buildAuditEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _auditLogs.length,
                        itemBuilder: (context, index) =>
                            _buildAuditLogTile(_auditLogs[index], isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            'No audit records found',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            'Actions like lock, unlock, adjustments will appear here',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTile(PayrollAuditLog log, bool isDark) {
    final colors = _auditActionColor(log.action);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action badge (left)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              log.action.replaceAll('_', '\n'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 7,
                fontWeight: FontWeight.w800,
                color: colors.fg,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Details (right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.employeeName != null && log.employeeName!.isNotEmpty)
                  Text(
                    log.employeeName!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                Text(
                  log.details,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 10, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                      log.performedByName,
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time_outlined, size: 10, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                      log.formattedTime,
                      style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Payslip Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPayslipCard(Payslip slip, bool isDark, bool isEmployee) {
    final statusColor = _statusColor(slip.status);
    final isLocked = slip.status.isLocked;
    final isBeingLocked = _lockingId == slip.employeeId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked
              ? const Color(0xFF4338CA).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openPayslipDetail(slip),
          child: Column(
            children: [
          // Top row: Avatar + Name + Net Pay + Lock badge
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    slip.employeeName.isNotEmpty ? slip.employeeName[0] : 'E',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4338CA),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slip.employeeName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${slip.designation} · ${slip.department}',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Net Pay + Status badge + Lock indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      slip.formattedNetPay,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Row(
                      children: [
                        if (isLocked)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock, size: 10, color: Color(0xFF4338CA)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slip.status.label.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats + action row
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                _buildStatChip(
                  Icons.calendar_today_outlined,
                  '${slip.presentDays}/${slip.totalWorkingDays} Days',
                  isDark,
                ),
                const SizedBox(width: 10),
                if (slip.overtimeHours > 0) ...[
                  _buildStatChip(
                    Icons.access_time_outlined,
                    '${slip.overtimeHours.toStringAsFixed(1)}h OT',
                    isDark,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                ],
                if (slip.unpaidLeaves > 0)
                  _buildStatChip(
                    Icons.event_busy_outlined,
                    '${slip.unpaidLeaves} LOP',
                    isDark,
                    color: const Color(0xFFEF4444),
                  ),
                const Spacer(),
                // View
                _buildActionBtn(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF6366F1),
                  onTap: () => _openPayslipDetail(slip),
                ),
                const SizedBox(width: 4),
                // PDF
                _buildActionBtn(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFF10B981),
                  onTap: () => _downloadPdf(slip),
                ),
                // Lock / Unlock (admin only)
                if (!isEmployee) ...[
                  const SizedBox(width: 4),
                  _buildLockBtn(slip, isDark, isBeingLocked),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildLockProgressBadge(int locked, int total, bool isDark) {
    final allLocked = locked == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: allLocked
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allLocked
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outlined,
            size: 12,
            color: allLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 6),
          Text(
            '$locked / $total Locked',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: allLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ),
          const Spacer(),
          Text(
            allLocked ? 'All payrolls finalized' : 'Tap lock icon on each slip to lock',
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockBtn(Payslip slip, bool isDark, bool isBeingLocked) {
    final isLocked = slip.status.isLocked;
    final isPaid = slip.status == PayrollStatus.paid;
    final lockColor = isLocked ? const Color(0xFF4338CA) : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: isPaid ? null : () => _toggleLock(slip, true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPaid
              ? Colors.grey.withValues(alpha: 0.1)
              : lockColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: isBeingLocked
            ? SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: lockColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    size: 11,
                    color: isPaid ? Colors.grey : lockColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isLocked ? 'Locked' : 'Lock',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.grey : lockColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No salary slips found',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            'Try changing the pay period or department filter',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String text,
    bool isDark, {
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Colour Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Color _statusColor(PayrollStatus status) {
    switch (status) {
      case PayrollStatus.paid:
        return const Color(0xFF10B981);
      case PayrollStatus.finalized:
        return const Color(0xFF4338CA);
      case PayrollStatus.processing:
        return const Color(0xFFF59E0B);
      case PayrollStatus.draft:
        return const Color(0xFF94A3B8);
      case PayrollStatus.approved:
        return const Color(0xFF3B82F6);
      case PayrollStatus.disbursed:
        return const Color(0xFF10B981);
    }
  }

  ({Color bg, Color fg}) _auditActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'LOCK':
        return (bg: const Color(0xFFE0E7FF), fg: const Color(0xFF4338CA));
      case 'UNLOCK':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFD97706));
      case 'PAY':
        return (bg: const Color(0xFFD1FAE5), fg: const Color(0xFF059669));
      case 'PACKAGE_CREATE':
      case 'PACKAGE_REVISION_CREATE':
        return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF7C3AED));
      case 'PACKAGE_UPDATE':
        return (bg: const Color(0xFFFCE7F3), fg: const Color(0xFF9D174D));
      case 'PACKAGE_DELETE':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFDC2626));
      case 'PACKAGE_ASSIGN':
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case 'PACKAGE_UNASSIGN':
        return (bg: const Color(0xFFFFEDD5), fg: const Color(0xFFEA580C));
      case 'ADJUSTMENT_UPDATE':
        return (bg: const Color(0xFFE0F2FE), fg: const Color(0xFF0369A1));
      default:
        return (bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569));
    }
  }
}

// [mod:2026-02-25T11:30:00+05:30]

// [rev:2026-08-25T11:00:00+05:30]
