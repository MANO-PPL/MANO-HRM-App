import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/features/payroll/widgets/payroll_summary_cards.dart';
import 'package:flutter_application/features/payroll/widgets/payroll_setup_banner.dart';
import 'package:flutter_application/features/payroll/widgets/run_payroll_drawer.dart';
import 'package:flutter_application/features/payroll/widgets/mark_paid_dialog.dart';
import 'package:flutter_application/features/payroll/widgets/payroll_settings_dialog.dart';
import 'package:flutter_application/features/payroll/widgets/create_package_dialog.dart';
import 'package:flutter_application/features/payroll/widgets/assign_package_dialog.dart';
import 'package:flutter_application/features/payroll/widgets/itemized_payslip_sheet.dart';
import 'package:flutter_application/shared/widgets/app_custom_dropdown.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// PayrollScreenMobile - Mobile Portrait View
/// Replicates Attendance-Web Payroll.jsx exactly:
/// 3-Tab unified navigation (Payroll Runs, Salary Packages, Package Assignments),
/// Run lifecycle actions (Draft, Recalculate, Approve, Mark as Paid),
/// Staff Payslip Breakdown, and Package Management.
class PayrollScreenMobile extends StatefulWidget {
  const PayrollScreenMobile({super.key});

  @override
  State<PayrollScreenMobile> createState() => _PayrollScreenMobileState();
}

class _PayrollScreenMobileState extends State<PayrollScreenMobile>
    with SingleTickerProviderStateMixin {
  late PayrollService _payrollService;
  late TabController _tabController;

  // General Loading & Setup
  bool _isLoading = true;
  PayrollSetupStatus _setupStatus = const PayrollSetupStatus(isConfigured: true, packagesCount: 1);

  // Tab 0: Runs Data
  List<PayrollRun> _runs = [];
  PayrollRun? _selectedRun;
  bool _runDetailsLoading = false;
  String _employeeSearch = '';
  bool _isRerunning = false;
  bool _isApproving = false;

  // Tab 1: Packages Data
  List<SalaryPackage> _packages = [];
  String _packageSearch = '';

  // Tab 2: Assignments Data
  List<EmployeePackageAssignment> _assignments = [];
  String _assignmentSearch = '';
  String _assignmentDept = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    _payrollService = PayrollService(authService.dio);
    _loadAllPayrollData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatINR(double val) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(val);
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadAllPayrollData() async {
    setState(() => _isLoading = true);
    try {
      final setupFuture = _payrollService.getSetupStatus();
      final runsFuture = _payrollService.getPayrollRuns();
      final packagesFuture = _payrollService.getPackages();
      final assignmentsFuture = _payrollService.getAssignments();

      final results = await Future.wait([
        setupFuture,
        runsFuture,
        packagesFuture,
        assignmentsFuture,
      ]);

      if (mounted) {
        final setup = results[0] as PayrollSetupStatus;
        final runsList = results[1] as List<PayrollRun>;
        final pkgsList = results[2] as List<SalaryPackage>;
        final assignsList = results[3] as List<EmployeePackageAssignment>;

        PayrollRun? activeRun;
        if (runsList.isNotEmpty) {
          activeRun = runsList.firstWhere(
            (r) => r.employees.isNotEmpty,
            orElse: () => runsList.first,
          );
        }

        setState(() {
          _setupStatus = setup;
          _runs = runsList;
          _selectedRun = activeRun;
          _packages = pkgsList;
          _assignments = assignsList;
          _isLoading = false;
        });

        if (activeRun != null) {
          _loadRunDetails(int.tryParse(activeRun.id) ?? 1);
        }
      }
    } catch (e) {
      debugPrint('Error loading mobile payroll data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRunDetails(int runId) async {
    setState(() => _runDetailsLoading = true);
    try {
      final details = await _payrollService.getPayrollRunDetails(runId);
      if (mounted && details != null) {
        setState(() {
          _selectedRun = details;
          _runDetailsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading run details: $e');
      if (mounted) setState(() => _runDetailsLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Run Lifecycle Handlers
  // ---------------------------------------------------------------------------

  Future<void> _handleRerunDraft() async {
    if (_selectedRun == null) return;
    setState(() => _isRerunning = true);
    final runId = int.tryParse(_selectedRun!.id) ?? 1;

    try {
      final res = await _payrollService.rerunPayrollRun(runId);
      if (mounted) {
        setState(() {
          if (res != null) _selectedRun = res;
          _isRerunning = false;
        });
        context.showToast('Draft run recalculation complete!', isSuccess: true);
        _refreshRunsList();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRerunning = false);
        context.showExceptionToast(e, fallback: 'Failed to recalculate draft');
      }
    }
  }

  Future<void> _handleApproveRun() async {
    if (_selectedRun == null) return;
    if (_selectedRun!.status != PayrollStatus.draft) {
      if (_selectedRun!.status == PayrollStatus.approved) {
        _openMarkPaidModal();
        return;
      }
      return;
    }

    final confirmed = await CustomDialog.show(
      context: context,
      title: 'Approve & Lock Payroll Run',
      message:
          'Approve and finalize "${_selectedRun!.batchName ?? 'Run #${_selectedRun!.id}'}"? This will lock all employee calculations and mark the run as approved.',
      positiveButtonText: 'Approve Run',
      positiveButtonColor: const Color(0xFF4F46E5),
      negativeButtonText: 'Cancel',
      icon: Icons.lock_outline,
      onPositivePressed: () {},
    );

    if (confirmed != true) return;

    setState(() => _isApproving = true);
    final runId = int.tryParse(_selectedRun!.id) ?? 1;

    try {
      final res = await _payrollService.approvePayrollRun(runId);
      if (mounted) {
        setState(() {
          if (res != null) {
            _selectedRun = res;
          } else {
            _selectedRun = PayrollRun(
              id: _selectedRun!.id,
              batchName: _selectedRun!.batchName,
              runType: _selectedRun!.runType,
              payPeriod: _selectedRun!.payPeriod,
              periodStart: _selectedRun!.periodStart,
              periodEnd: _selectedRun!.periodEnd,
              status: PayrollStatus.approved,
              totalEmployees: _selectedRun!.totalEmployees,
              totalGrossPayout: _selectedRun!.totalGrossPayout,
              totalDeductions: _selectedRun!.totalDeductions,
              totalNetPayout: _selectedRun!.totalNetPayout,
              processedDate: _selectedRun!.processedDate,
              isLocked: true,
              summary: _selectedRun!.summary,
              employees: _selectedRun!.employees,
            );
          }
          _isApproving = false;
        });
        context.showToast('Payroll run approved and locked!', isSuccess: true);
        _refreshRunsList();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApproving = false);
        context.showExceptionToast(e, fallback: 'Failed to approve run');
      }
    }
  }

  void _openMarkPaidModal() {
    if (_selectedRun == null) return;
    MarkPaidDialog.show(
      context,
      run: _selectedRun!,
      payrollService: _payrollService,
      onPaidConfirmed: (paidRun) {
        setState(() => _selectedRun = paidRun);
        _refreshRunsList();
      },
    );
  }

  Future<void> _refreshRunsList() async {
    final updated = await _payrollService.getPayrollRuns();
    if (mounted) {
      setState(() => _runs = updated);
    }
  }

  void _openSettingsDialog() {
    PayrollSettingsDialog.show(
      context,
      initialSettings: _setupStatus.settings ?? const PayrollSettings(),
      payrollService: _payrollService,
      onSettingsSaved: (newSettings) {
        setState(() {
          _setupStatus = PayrollSetupStatus(
            isConfigured: true,
            packagesCount: _setupStatus.packagesCount,
            settings: newSettings,
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsSetup = (_setupStatus.packagesCount == 0 || !_setupStatus.isConfigured) && _runs.isEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Column(
              children: [
                // Top Tab Bar & Quick Actions Row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: isDark ? const Color(0xFF21262D) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: const Color(0xFF4F46E5),
                            unselectedLabelColor: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                            labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                            labelPadding: EdgeInsets.zero,
                            tabs: [
                              Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.receipt_long_outlined, size: 13),
                                      const SizedBox(width: 4),
                                      const Text('Runs'),
                                      if (_runs.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_runs.length}',
                                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.layers_outlined, size: 13),
                                      SizedBox(width: 4),
                                      Text('Packages'),
                                    ],
                                  ),
                                ),
                              ),
                              const Tab(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.people_outline, size: 13),
                                      SizedBox(width: 4),
                                      Text('Assignments'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 19),
                        tooltip: 'Payroll Settings',
                        onPressed: _openSettingsDialog,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        splashRadius: 18,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 19),
                        tooltip: 'Refresh',
                        onPressed: _loadAllPayrollData,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 0: PAYROLL RUNS
                      _buildRunsTab(needsSetup),

                      // TAB 1: SALARY PACKAGES
                      _buildPackagesTab(),

                      // TAB 2: PACKAGE ASSIGNMENTS
                      _buildAssignmentsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // TAB 0: PAYROLL RUNS VIEW
  // ===========================================================================

  Widget _buildRunsTab(bool needsSetup) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _selectedRun?.summary ?? const PayrollRunSummary();

    final filteredEmployees = (_selectedRun?.employees ?? []).where((emp) {
      if (_employeeSearch.isEmpty) return true;
      final q = _employeeSearch.toLowerCase().trim();
      return emp.employeeName.toLowerCase().contains(q) ||
          emp.employeeCode.toLowerCase().contains(q) ||
          emp.department.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllPayrollData,
      color: const Color(0xFF4F46E5),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Onboarding Setup Banner (if needed)
          if (needsSetup) ...[
            PayrollSetupBanner(onConfigureSettings: _openSettingsDialog),
            const SizedBox(height: 12),
          ],

          // Quick Action Bar: Run Payroll + Run Switcher (when runs exist)
          if (_runs.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 28, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Payroll Runs Yet',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You have not executed any payroll runs yet. Execute "Run Payroll" to calculate employee pay for this cycle.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      RunPayrollSheet.show(
                        context,
                        payrollService: _payrollService,
                        employees: _assignments,
                        onRunCreated: (newRun) {
                          setState(() {
                            _runs.insert(0, newRun);
                            _selectedRun = newRun;
                          });
                          _loadRunDetails(int.tryParse(newRun.id) ?? 1);
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('Run Payroll', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      RunPayrollSheet.show(
                        context,
                        payrollService: _payrollService,
                        employees: _assignments,
                        onRunCreated: (newRun) {
                          setState(() {
                            _runs.insert(0, newRun);
                            _selectedRun = newRun;
                          });
                          _loadRunDetails(int.tryParse(newRun.id) ?? 1);
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text('Run Payroll', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),

                // Run Switcher Dropdown
                SizedBox(
                  width: 165,
                  child: AppCustomDropdown<String>(
                    hintText: 'Select Run',
                    initialValue: _selectedRun?.id,
                    isDense: true,
                    prefixIcon: Icons.receipt_long_outlined,
                    items: _runs.map((r) {
                      return AppDropdownItem<String>(
                        value: r.id,
                        label: '#${r.id} • ${r.batchName ?? 'Batch'}',
                        badge: r.status.name.toUpperCase(),
                        badgeColor: r.status == PayrollStatus.paid
                            ? const Color(0xFF10B981)
                            : r.status == PayrollStatus.approved
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF6B7280),
                        badgeTextColor: Colors.white,
                        icon: Icons.receipt_outlined,
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final id = int.tryParse(val) ?? 1;
                        final r = _runs.firstWhere((e) => e.id == val, orElse: () => _runs.first);
                        setState(() => _selectedRun = r);
                        _loadRunDetails(id);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // KPI Summary Cards
            PayrollSummaryCards(summary: summary),
            const SizedBox(height: 14),

          // Action Toolbar & Search
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header text & Lifecycle Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff Payslips Breakdown',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Showing ${filteredEmployees.length} entries for this period',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                          ),
                        ),
                      ],
                    ),

                    // Lifecycle Actions
                    if (_selectedRun?.status == PayrollStatus.draft) ...[
                      Row(
                        children: [
                          // Recalculate
                          IconButton(
                            icon: _isRerunning
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 16),
                            tooltip: 'Recalculate attendance & overtime',
                            onPressed: _isRerunning ? null : _handleRerunDraft,
                          ),
                          const SizedBox(width: 4),
                          // Review & Approve
                          ElevatedButton.icon(
                            onPressed: _isApproving ? null : _handleApproveRun,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: _isApproving
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.shield_outlined, size: 13),
                            label: Text(
                              _isApproving ? 'Approving...' : 'Approve',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_selectedRun?.status == PayrollStatus.approved) ...[
                      ElevatedButton.icon(
                        onPressed: _openMarkPaidModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 13),
                        label: Text('Disburse & Pay', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ] else if (_selectedRun?.status == PayrollStatus.paid) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              'Paid & Disbursed',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF065F46)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Search Box
                TextField(
                  onChanged: (val) => setState(() => _employeeSearch = val),
                  decoration: InputDecoration(
                    hintText: 'Search employee or department...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Staff Payslips List
          if (_runDetailsLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            )
          else if (filteredEmployees.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_alt_outlined, size: 36, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                  const SizedBox(height: 8),
                  Text(
                    _employeeSearch.isNotEmpty ? 'No matching staff members found.' : 'No employee records in this payroll run.',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use the Selected Run dropdown above to switch to an active run or click Run Payroll.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ...List.generate(filteredEmployees.length, (idx) {
              final emp = filteredEmployees[idx];
              final lopLine = emp.lopLine;
              final otLine = emp.otLine;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Employee Name & Department & View Payslip button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.employeeName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${emp.department} • ${emp.employeeCode}',
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            final runId = int.tryParse(_selectedRun?.id ?? '1') ?? 1;
                            ItemizedPayslipSheet.show(
                              context,
                              runId: runId,
                              employeeId: emp.employeeId,
                              initialEmployee: emp,
                              run: _selectedRun,
                              payrollService: _payrollService,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF4F46E5)),
                          label: Text(
                            'View Payslip',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Metrics row: Gross | Adjustments | Deductions | Net
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSmallStat('Gross', '₹${_formatINR(emp.grossPay)}'),
                        _buildSmallStat('Deductions', '-₹${_formatINR(emp.totalDeductions)}', color: const Color(0xFFF43F5E)),
                        _buildSmallStat('Net Take-Home', '₹${_formatINR(emp.netPay)}', color: const Color(0xFF10B981), isBold: true),
                      ],
                    ),

                    // Adjustments Chips (LOP, OT, etc.)
                    if (lopLine != null || otLine != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (lopLine != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Text(
                                'LOP: -₹${_formatINR(lopLine.amount)}',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFFBE123C)),
                              ),
                            ),
                          if (otLine != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                'OT: +₹${_formatINR(otLine.amount)}',
                                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, {Color? color, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey)),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: SALARY PACKAGES VIEW
  // ===========================================================================

  Widget _buildPackagesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredPackages = _packages.where((p) {
      if (_packageSearch.isEmpty) return true;
      final q = _packageSearch.toLowerCase();
      return p.name.toLowerCase().contains(q) || (p.description ?? '').toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final pkgs = await _payrollService.getPackages();
        if (mounted) setState(() => _packages = pkgs);
      },
      color: const Color(0xFF4F46E5),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Header with Search & "New Package" Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _packageSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search packages...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  CreatePackageDialog.show(
                    context,
                    payrollService: _payrollService,
                    onPackageSaved: (newPkg) {
                      setState(() => _packages.add(newPkg));
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 15),
                label: Text('New Package', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Packages List
          if (filteredPackages.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
              ),
              child: Column(
                children: [
                  Icon(Icons.layers_outlined, size: 36, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                  const SizedBox(height: 8),
                  Text('No salary packages found', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Click "New Package" to configure a compensation package.', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                ],
              ),
            )
          else
            ...filteredPackages.map((pkg) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pkg.name,
                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                              if (pkg.description != null && pkg.description!.isNotEmpty)
                                Text(
                                  pkg.description!,
                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () {
                                CreatePackageDialog.show(
                                  context,
                                  payrollService: _payrollService,
                                  initialPackage: pkg,
                                  onPackageSaved: (updated) {
                                    setState(() {
                                      final idx = _packages.indexWhere((p) => p.id == updated.id);
                                      if (idx >= 0) _packages[idx] = updated;
                                    });
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              onPressed: () async {
                                final ok = await CustomDialog.show(
                                  context: context,
                                  title: 'Delete Package',
                                  message: 'Are you sure you want to delete "${pkg.name}"?',
                                  positiveButtonText: 'Delete',
                                  negativeButtonText: 'Cancel',
                                  isDestructive: true,
                                  icon: Icons.delete_outline,
                                  onPositivePressed: () {},
                                );
                                if (ok == true) {
                                  final pId = int.tryParse(pkg.id) ?? 0;
                                  await _payrollService.deletePackage(pId);
                                  setState(() => _packages.removeWhere((p) => p.id == pkg.id));
                                  if (mounted) {
                                    context.showToast('Package deleted successfully', isSuccess: true);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Gross & Annual CTC
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MONTHLY GROSS', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey)),
                              Text('₹${_formatINR(pkg.monthlyGross)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ANNUAL CTC', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey)),
                              Text('₹${_formatINR(pkg.annualCtc)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Badges (Components count, Overtime)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${pkg.components.length} Components (${pkg.earningsCount} Earn / ${pkg.deductionsCount} Ded)',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (pkg.overtimeEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OT Eligible (₹${pkg.overtimeRate.toStringAsFixed(0)}/hr)',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF047857)),
                            ),
                          ),
                        if (pkg.lopEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LOP: ${pkg.lopDayBasis == 'fixed_30' ? 'Fixed 30' : pkg.lopDayBasis == 'fixed_26' ? 'Fixed 26' : pkg.lopDayBasis == 'working_days' ? 'Working Days' : 'Calendar Days'}',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PACKAGE ASSIGNMENTS VIEW
  // ===========================================================================

  Widget _buildAssignmentsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final depts = <String>{'All'};
    for (final a in _assignments) {
      if (a.department.isNotEmpty) depts.add(a.department);
    }

    final filtered = _assignments.where((a) {
      final matchesSearch = _assignmentSearch.isEmpty ||
          a.name.toLowerCase().contains(_assignmentSearch.toLowerCase()) ||
          a.code.toLowerCase().contains(_assignmentSearch.toLowerCase()) ||
          a.department.toLowerCase().contains(_assignmentSearch.toLowerCase());
      final matchesDept = _assignmentDept == 'All' || a.department == _assignmentDept;
      return matchesSearch && matchesDept;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        final assigns = await _payrollService.getAssignments();
        if (mounted) setState(() => _assignments = assigns);
      },
      color: const Color(0xFF4F46E5),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Search & Department Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _assignmentSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search staff name or code...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: AppCustomDropdown<String>(
                  hintText: 'Department',
                  initialValue: _assignmentDept,
                  isDense: true,
                  prefixIcon: Icons.business_outlined,
                  items: depts.map((d) {
                    return AppDropdownItem<String>(
                      value: d,
                      label: d,
                      icon: Icons.business_outlined,
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _assignmentDept = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Assignments List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 36, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text('No employees found', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else
            ...filtered.map((emp) {
              final isAssigned = emp.isAssigned;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isAssigned ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB),
                      child: Text(
                        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'S',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isAssigned ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${emp.designation} • ${emp.department} • ${emp.code}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          if (isAssigned)
                            Text(
                              '${emp.packageName} (₹${_formatINR(emp.grossSalary)}/mo)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4F46E5),
                              ),
                            )
                          else
                            Text(
                              'No package assigned',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        AssignPackageDialog.show(
                          context,
                          employee: emp,
                          packages: _packages,
                          payrollService: _payrollService,
                          onAssigned: () async {
                            final updated = await _payrollService.getAssignments();
                            if (mounted) setState(() => _assignments = updated);
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAssigned ? const Color(0xFFEEF2FF) : const Color(0xFF4F46E5),
                        foregroundColor: isAssigned ? const Color(0xFF4F46E5) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(
                        isAssigned ? 'Change' : 'Assign',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
