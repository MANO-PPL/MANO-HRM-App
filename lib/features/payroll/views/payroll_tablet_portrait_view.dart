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

/// PayrollScreenTablet - Tablet View
/// Replicates Attendance-Web Payroll.jsx on wide tablet screens with dual-pane layout option,
/// full run lifecycle management, package directory, and staff assignment.
class PayrollScreenTablet extends StatefulWidget {
  final bool? isLandscape;
  const PayrollScreenTablet({super.key, this.isLandscape});

  @override
  State<PayrollScreenTablet> createState() => _PayrollScreenTabletState();
}

class _PayrollScreenTabletState extends State<PayrollScreenTablet>
    with SingleTickerProviderStateMixin {
  late PayrollService _payrollService;
  late TabController _tabController;

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
  SalaryPackage? _selectedPackage;
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
          _selectedPackage = pkgsList.isNotEmpty ? pkgsList.first : null;
          _assignments = assignsList;
          _isLoading = false;
        });

        if (activeRun != null) {
          _loadRunDetails(int.tryParse(activeRun.id) ?? 1);
        }
      }
    } catch (e) {
      debugPrint('Error loading tablet payroll data: $e');
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
        context.showExceptionToast(e, fallback: 'Failed to rerun draft');
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
    if (mounted) setState(() => _runs = updated);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isLandscape = widget.isLandscape ??
        (media.orientation == Orientation.landscape || media.size.width >= 900);
    final needsSetup = (_setupStatus.packagesCount == 0 || !_setupStatus.isConfigured) && _runs.isEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : SafeArea(
              top: false,
              bottom: true,
              child: Column(
                children: [
                  _buildHeader(isDark, isLandscape),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRunsTab(needsSetup, isLandscape),
                        _buildPackagesTab(isLandscape),
                        _buildAssignmentsTab(isLandscape),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // TOP HEADER & NAVIGATION
  // ===========================================================================

  Widget _buildHeader(bool isDark, bool isLandscape) {
    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            // Tab Switcher
            Container(
              height: 40,
              width: 380,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(3),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: _buildTabList(),
              ),
            ),
            const Spacer(),
            // Actions
            ElevatedButton.icon(
              onPressed: _openRunPayrollSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: Text('Run Payroll', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            _buildIconActionButton(
              icon: Icons.settings_outlined,
              tooltip: 'Payroll Settings',
              onTap: _openSettingsDialog,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildIconActionButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh Payroll Data',
              onTap: _loadAllPayrollData,
              isDark: isDark,
            ),
          ],
        ),
      );
    } else {
      // Tablet Portrait: Clean Minimal Single Row with Tabs & Actions
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
                  tabs: _buildTabList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _openRunPayrollSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text('Run Payroll', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            _buildIconActionButton(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: _openSettingsDialog,
              isDark: isDark,
            ),
            const SizedBox(width: 4),
            _buildIconActionButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: _loadAllPayrollData,
              isDark: isDark,
            ),
          ],
        ),
      );
    }
  }

  List<Widget> _buildTabList() {
    return [
      Tab(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_outlined, size: 14),
              const SizedBox(width: 5),
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
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
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
              Icon(Icons.layers_outlined, size: 14),
              SizedBox(width: 5),
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
              Icon(Icons.people_outline, size: 14),
              SizedBox(width: 5),
              Text('Assignments'),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF475569)),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _openRunPayrollSheet() {
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
  }

  void _openPayslip(dynamic emp) {
    final runId = int.tryParse(_selectedRun?.id ?? '1') ?? 1;
    ItemizedPayslipSheet.show(
      context,
      runId: runId,
      employeeId: emp.employeeId,
      initialEmployee: emp,
      run: _selectedRun,
      payrollService: _payrollService,
    );
  }

  void _openAssignDialog(EmployeePackageAssignment emp) {
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
  }

  // ===========================================================================
  // TAB 0: RUNS
  // ===========================================================================

  Widget _buildRunsTab(bool needsSetup, bool isLandscape) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _selectedRun?.summary ?? const PayrollRunSummary();

    final filteredEmployees = (_selectedRun?.employees ?? []).where((emp) {
      if (_employeeSearch.isEmpty) return true;
      final q = _employeeSearch.toLowerCase().trim();
      return emp.employeeName.toLowerCase().contains(q) ||
          emp.employeeCode.toLowerCase().contains(q) ||
          emp.department.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      children: [
        if (needsSetup) ...[
          PayrollSetupBanner(onConfigureSettings: _openSettingsDialog),
          const SizedBox(height: 10),
        ],

        if (_runs.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.receipt_long_outlined, size: 30, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Payroll Runs Yet',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have not executed any payroll runs yet. Execute "Run Payroll" to calculate employee pay for this cycle.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _openRunPayrollSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text('Run Payroll', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ] else ...[
          // KPI Summary Cards
          PayrollSummaryCards(summary: summary),
          const SizedBox(height: 10),

          // Main Table/Cards Container
          Material(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Responsive Toolbar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final searchField = SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (v) => setState(() => _employeeSearch = v),
                          style: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search staff by name, code or department...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                            ),
                          ),
                        ),
                      );

                      final runSwitcher = _runs.isEmpty
                          ? const SizedBox.shrink()
                          : SizedBox(
                              width: 220,
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
                                onChanged: (v) {
                                  if (v != null) {
                                    final id = int.tryParse(v) ?? 1;
                                    final r = _runs.firstWhere((e) => e.id == v, orElse: () => _runs.first);
                                    setState(() => _selectedRun = r);
                                    _loadRunDetails(id);
                                  }
                                },
                              ),
                            );

                      Widget? lifecycleWidget;
                      if (_selectedRun?.status == PayrollStatus.draft) {
                        lifecycleWidget = Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isRerunning ? null : _handleRerunDraft,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF334155),
                                side: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Recalculate'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isApproving ? null : _handleApproveRun,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                              icon: const Icon(Icons.shield_outlined, size: 14),
                              label: const Text('Review & Approve'),
                            ),
                          ],
                        );
                      } else if (_selectedRun?.status == PayrollStatus.approved) {
                        lifecycleWidget = ElevatedButton.icon(
                          onPressed: _openMarkPaidModal,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                          label: const Text('Disburse & Mark Paid'),
                        );
                      } else if (_selectedRun?.status == PayrollStatus.paid) {
                        lifecycleWidget = Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text('Paid & Disbursed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))),
                            ],
                          ),
                        );
                      }

                      if (isLandscape) {
                        // Wide toolbar in landscape using responsive Wrap to guarantee zero overflow
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Staff Payslips Breakdown', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                Text('Showing ${filteredEmployees.length} employee records for this cycle', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(width: 200, child: searchField),
                                if (_runs.isNotEmpty)
                                  SizedBox(width: 210, child: runSwitcher),
                                if (lifecycleWidget != null) lifecycleWidget,
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Portrait toolbar
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Staff Payslips Breakdown',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '${filteredEmployees.length} employee entries',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                if (lifecycleWidget != null) lifecycleWidget,
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(flex: 3, child: searchField),
                                if (_runs.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(flex: 2, child: runSwitcher),
                                ],
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),

                // Table or Responsive Cards
                if (_runDetailsLoading)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (filteredEmployees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No employee records in this payroll run.',
                        style: TextStyle(color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                      ),
                    ),
                  )
                else if (isLandscape)
                  // Landscape Data Table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 850),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.2),
                          1: FlexColumnWidth(1.4),
                          2: FlexColumnWidth(1.4),
                          3: FlexColumnWidth(2.0),
                          4: FlexColumnWidth(1.4),
                          5: FlexColumnWidth(1.5),
                          6: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC)),
                            children: [
                              Padding(padding: const EdgeInsets.all(12), child: Text('EMPLOYEE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('DEPARTMENT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('GROSS EARNINGS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('ADJUSTMENTS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('DEDUCTIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('NET TAKE-HOME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                              Padding(padding: const EdgeInsets.all(12), child: Text('ACTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)))),
                            ],
                          ),
                          ...filteredEmployees.map((emp) {
                            final lop = emp.lopLine;
                            final ot = emp.otLine;
                            return TableRow(
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE5E7EB)))),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                                        child: Text(
                                          emp.employeeName.isNotEmpty ? emp.employeeName[0].toUpperCase() : 'E',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp.employeeName,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              emp.employeeCode,
                                              style: GoogleFonts.inter(fontSize: 10, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    emp.department,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: isDark ? const Color(0xFFD0D7DE) : const Color(0xFF334155)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '₹${_formatINR(emp.grossPay)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      if (lop != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF4C0519).withValues(alpha: 0.6) : const Color(0xFFFFF1F2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3)),
                                          ),
                                          child: Text(
                                            'LOP: -₹${_formatINR(lop.amount)}',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (ot != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                          ),
                                          child: Text(
                                            'OT: +₹${_formatINR(ot.amount)}',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '-₹${_formatINR(emp.totalDeductions)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFFB7185) : const Color(0xFFF43F5E),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    '₹${_formatINR(emp.netPay)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: OutlinedButton(
                                    onPressed: () => _openPayslip(emp),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? const Color(0xFF58A6FF) : const Color(0xFF4F46E5),
                                      side: BorderSide(color: isDark ? const Color(0xFF388BFD) : const Color(0xFF4F46E5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    child: const Text('View Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  )
                else
                  // Portrait Responsive Cards List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredEmployees.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final emp = filteredEmployees[idx];
                      final lop = emp.lopLine;
                      final ot = emp.otLine;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                                  child: Text(
                                    emp.employeeName.isNotEmpty ? emp.employeeName[0].toUpperCase() : 'E',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.employeeName,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '${emp.department} • ${emp.employeeCode}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'NET PAY',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                        ),
                                      ),
                                      Text(
                                        '₹${_formatINR(emp.netPay)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Divider(height: 1, color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSmallStat('GROSS', '₹${_formatINR(emp.grossPay)}', isBold: true),
                                ),
                                Expanded(
                                  child: _buildSmallStat(
                                    'DEDUCTIONS',
                                    '-₹${_formatINR(emp.totalDeductions)}',
                                    color: isDark ? const Color(0xFFFB7185) : const Color(0xFFF43F5E),
                                    isBold: true,
                                  ),
                                ),
                                if (lop != null || ot != null)
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: [
                                        if (lop != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF4C0519).withValues(alpha: 0.6) : const Color(0xFFFFF1F2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isDark ? const Color(0xFFBE123C) : const Color(0xFFFECDD3)),
                                            ),
                                            child: Text(
                                              'LOP: -₹${_formatINR(lop.amount)}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        if (ot != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.6) : const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                            ),
                                            child: Text(
                                              'OT: +₹${_formatINR(ot.amount)}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                OutlinedButton(
                                  onPressed: () => _openPayslip(emp),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFF58A6FF) : const Color(0xFF4F46E5),
                                    side: BorderSide(color: isDark ? const Color(0xFF388BFD) : const Color(0xFF4F46E5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('View Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 1: SALARY PACKAGES
  // ===========================================================================

  Widget _buildPackagesTab(bool isLandscape) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _packages.where((p) {
      if (_packageSearch.isEmpty) return true;
      final q = _packageSearch.toLowerCase();
      return p.name.toLowerCase().contains(q) || (p.description ?? '').toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = isLandscape || constraints.maxWidth >= 850;
        final directoryWidth = isWide ? 340.0 : (constraints.maxWidth * 0.38).clamp(240.0, 300.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 4, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Directory Panel
              SizedBox(
                width: directoryWidth,
                child: Material(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Packages (${filtered.length})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                CreatePackageDialog.show(
                                  context,
                                  payrollService: _payrollService,
                                  onPackageSaved: (p) => setState(() => _packages.add(p)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('New', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          onChanged: (v) => setState(() => _packageSearch = v),
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFF0F6FC) : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Search packages...',
                            hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                          itemBuilder: (ctx, idx) {
                            final pkg = filtered[idx];
                            final isSel = _selectedPackage?.id == pkg.id;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isSel ? const Color(0xFF6366F1) : Colors.transparent,
                                    width: 3.5,
                                  ),
                                ),
                              ),
                              child: Material(
                                color: isSel
                                    ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFEEF2FF))
                                    : Colors.transparent,
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    pkg.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                      color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '₹${_formatINR(pkg.monthlyGross)}/mo • ${pkg.components.length} Items',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: Icon(Icons.chevron_right, size: 16, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                                  onTap: () => setState(() => _selectedPackage = pkg),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Details Panel
              Expanded(
                child: _selectedPackage == null
                    ? Center(
                        child: Text(
                          'Select a package to view breakdown.',
                          style: TextStyle(color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPackage!.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_selectedPackage!.description != null)
                                        Text(
                                          _selectedPackage!.description!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF8B949E) : Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    CreatePackageDialog.show(
                                      context,
                                      payrollService: _payrollService,
                                      initialPackage: _selectedPackage,
                                      onPackageSaved: (updated) {
                                        setState(() {
                                          final idx = _packages.indexWhere((p) => p.id == updated.id);
                                          if (idx >= 0) _packages[idx] = updated;
                                          _selectedPackage = updated;
                                        });
                                      },
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? const Color(0xFF58A6FF) : const Color(0xFF4F46E5),
                                    side: BorderSide(color: isDark ? const Color(0xFF388BFD) : const Color(0xFF4F46E5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    if (_selectedPackage == null) return;
                                    final ok = await CustomDialog.show(
                                      context: context,
                                      title: 'Delete Package',
                                      message: 'Are you sure you want to delete "${_selectedPackage!.name}"?',
                                      positiveButtonText: 'Delete',
                                      negativeButtonText: 'Cancel',
                                      isDestructive: true,
                                      icon: Icons.delete_outline_rounded,
                                      iconColor: const Color(0xFFEF4444),
                                      onPositivePressed: () {},
                                    );
                                    if (ok == true) {
                                      final pId = int.tryParse(_selectedPackage!.id) ?? 0;
                                      await _payrollService.deletePackage(pId);
                                      setState(() {
                                        _packages.removeWhere((p) => p.id == _selectedPackage!.id);
                                        _selectedPackage = _packages.isNotEmpty ? _packages.first : null;
                                      });
                                      if (mounted) {
                                        context.showToast('Package deleted successfully', isSuccess: true);
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                  label: const Text('Delete', style: TextStyle(fontSize: 11.5)),
                                ),
                              ],
                            ),
                            Divider(height: 22, color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),

                            // Stats Grid: 4 in a row for Landscape, 2x2 for Portrait
                            if (isWide)
                              Row(
                                children: [
                                  Expanded(child: _buildMetricCard('MONTHLY GROSS', '₹${_formatINR(_selectedPackage!.monthlyGross)}', isDark, isBold: true)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildMetricCard('ANNUAL CTC', '₹${_formatINR(_selectedPackage!.annualCtc)}', isDark, isBold: true)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildMetricCard('OVERTIME', _selectedPackage!.overtimeEnabled ? '₹${_selectedPackage!.overtimeRate.toStringAsFixed(0)}/hr' : 'Disabled', isDark)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildMetricCard('LOP DIVISOR', _selectedPackage!.lopEnabled ? (_selectedPackage!.lopDayBasis == 'fixed_30' ? 'Fixed 30' : _selectedPackage!.lopDayBasis == 'fixed_26' ? 'Fixed 26' : _selectedPackage!.lopDayBasis == 'working_days' ? 'Working Days' : 'Calendar Days') : 'Disabled', isDark)),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildMetricCard('MONTHLY GROSS', '₹${_formatINR(_selectedPackage!.monthlyGross)}', isDark, isBold: true)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildMetricCard('ANNUAL CTC', '₹${_formatINR(_selectedPackage!.annualCtc)}', isDark, isBold: true)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: _buildMetricCard('OVERTIME', _selectedPackage!.overtimeEnabled ? '₹${_selectedPackage!.overtimeRate.toStringAsFixed(0)}/hr' : 'Disabled', isDark)),
                                      const SizedBox(width: 8),
                                      Expanded(child: _buildMetricCard('LOP DIVISOR', _selectedPackage!.lopEnabled ? (_selectedPackage!.lopDayBasis == 'fixed_30' ? 'Fixed 30' : _selectedPackage!.lopDayBasis == 'fixed_26' ? 'Fixed 26' : _selectedPackage!.lopDayBasis == 'working_days' ? 'Working Days' : 'Calendar Days') : 'Disabled', isDark)),
                                    ],
                                  ),
                                ],
                              ),
                            const SizedBox(height: 18),

                            Text(
                              'Components Breakdown',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView(
                                children: _selectedPackage!.components.map((c) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF21262D) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE5E7EB)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              c.isEarning
                                                  ? 'Earning (+) • Monthly'
                                                  : c.isEmployerContribution
                                                      ? 'Employer Cost (CTC) • Monthly'
                                                      : c.isBenefit
                                                          ? 'Benefit (Perk) • Monthly'
                                                          : 'Deduction (-) • Monthly',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: c.isEarning
                                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                                    : c.isEmployerContribution
                                                        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                                        : c.isBenefit
                                                            ? (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED))
                                                            : (isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '₹${c.value.toStringAsFixed(0)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: ASSIGNMENTS
  // ===========================================================================

  Widget _buildAssignmentsTab(bool isLandscape) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = isLandscape || constraints.maxWidth >= 880;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 4, 16, 14),
          child: Material(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Toolbar
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: isWide
                      ? Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            Text(
                              'Staff Package Assignments (${filtered.length})',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 220,
                                  height: 38,
                                  child: TextField(
                                    onChanged: (v) => setState(() => _assignmentSearch = v),
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFF0F6FC) : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: 'Search staff...',
                                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8)),
                                      prefixIcon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 150,
                                  child: AppCustomDropdown<String>(
                                    hintText: 'Department',
                                    initialValue: _assignmentDept,
                                    isDense: true,
                                    prefixIcon: Icons.business_outlined,
                                    items: depts.map((d) => AppDropdownItem<String>(
                                      value: d,
                                      label: d,
                                      icon: Icons.business_outlined,
                                    )).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _assignmentDept = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Staff Package Assignments (${filtered.length})',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      onChanged: (v) => setState(() => _assignmentSearch = v),
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFF0F6FC) : Colors.black87),
                                      decoration: InputDecoration(
                                        hintText: 'Search staff...',
                                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8)),
                                        prefixIcon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
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
                                    items: depts.map((d) => AppDropdownItem<String>(
                                      value: d,
                                      label: d,
                                      icon: Icons.business_outlined,
                                    )).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _assignmentDept = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),

                // Grid (in Landscape) or Card List (in Portrait)
                Expanded(
                  child: isWide
                      ? GridView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 96,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (ctx, idx) {
                            final emp = filtered[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: emp.isAssigned
                                        ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                                        : (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB)),
                                    child: Text(
                                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'S',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: emp.isAssigned
                                            ? (isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5))
                                            : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          emp.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${emp.designation} • ${emp.code}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        if (emp.isAssigned)
                                          Text(
                                            '${emp.packageName} (₹${_formatINR(emp.grossSalary)}/mo)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else
                                          Text(
                                            'No Package Assigned',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? const Color(0xFFFBBF24) : Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _openAssignDialog(emp),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: emp.isAssigned
                                          ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF))
                                          : const Color(0xFF4F46E5),
                                      foregroundColor: emp.isAssigned
                                          ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                          : Colors.white,
                                      side: emp.isAssigned && isDark ? const BorderSide(color: Color(0xFF4338CA)) : null,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      elevation: 0,
                                    ),
                                    child: Text(emp.isAssigned ? 'Change' : 'Assign', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final emp = filtered[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: emp.isAssigned
                                            ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                                            : (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB)),
                                        child: Text(
                                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'S',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: emp.isAssigned
                                                ? (isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5))
                                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706)),
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
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              '${emp.department} • ${emp.code}',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (emp.isAssigned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? const Color(0xFF6366F1) : const Color(0xFFC7D2FE)),
                                          ),
                                          child: Text(
                                            '${emp.packageName} • ₹${_formatINR(emp.grossSalary)}/mo',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            'No Package',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        emp.designation,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _openAssignDialog(emp),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: emp.isAssigned
                                              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF))
                                              : const Color(0xFF4F46E5),
                                          foregroundColor: emp.isAssigned
                                              ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                              : Colors.white,
                                          side: emp.isAssigned && isDark ? const BorderSide(color: Color(0xFF4338CA)) : null,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          elevation: 0,
                                        ),
                                        child: Text(emp.isAssigned ? 'Change Package' : 'Assign Package', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, bool isDark, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF383E47) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value, {Color? color, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? (isDark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
