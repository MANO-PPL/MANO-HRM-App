import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/features/payroll/core/payslip_pdf_service.dart';
import 'package:flutter_application/features/payroll/widgets/salary_breakdown_card.dart';

class PayslipDetailScreenMobile extends StatefulWidget {
  final Payslip payslip;
  final PayrollService? payrollService;
  final bool? isAdmin;
  final VoidCallback? onStatusChanged;

  const PayslipDetailScreenMobile({
    super.key,
    required this.payslip,
    this.payrollService,
    this.isAdmin,
    this.onStatusChanged,
  });

  @override
  State<PayslipDetailScreenMobile> createState() =>
      _PayslipDetailScreenMobileState();
}

class _PayslipDetailScreenMobileState
    extends State<PayslipDetailScreenMobile> {
  late Payslip _currentPayslip;
  late PayrollService _payrollService;
  bool _isGeneratingPdf = false;
  bool _isOpeningPdf = false;
  bool _isLocking = false;
  String? _lastGeneratedPdfPath;

  @override
  void initState() {
    super.initState();
    _currentPayslip = widget.payslip;
    if (widget.payrollService != null) {
      _payrollService = widget.payrollService!;
    } else {
      final auth = Provider.of<AuthService>(context, listen: false);
      _payrollService = PayrollService(auth.dio);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleDownloadPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final path =
          await PayslipPdfService.generateAndSavePayslipPdf(_currentPayslip);
      _lastGeneratedPdfPath = path;
      if (mounted) {
        context.showToast(
          'PDF Payslip downloaded: ${path.split('/').last}',
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
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleOpenPdf() async {
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    try {
      String path = _lastGeneratedPdfPath ?? '';
      if (path.isEmpty) {
        path = await PayslipPdfService.generateAndSavePayslipPdf(_currentPayslip);
        _lastGeneratedPdfPath = path;
      }
      await PayslipPdfService.openPayslipPdf(path);
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: 'Failed to open PDF');
      }
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  Future<void> _handleToggleLock(bool isAdmin) async {
    if (!isAdmin || _isLocking) return;
    final isLocked = _currentPayslip.status.isLocked;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isLocked ? 'Unlock Payroll?' : 'Lock & Finalize?',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isLocked
                ? 'This will revert ${_currentPayslip.employeeName}\'s payroll back to Draft status so manual changes or attendance recalculations can be made.'
                : 'This will lock ${_currentPayslip.employeeName}\'s calculations for ${_currentPayslip.payPeriod} and finalize this payslip.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                isLocked ? 'Unlock' : 'Lock & Finalize',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLocking = true);
    try {
      if (isLocked) {
        await _payrollService.unlockEmployee(
          employeeId: _currentPayslip.employeeId,
          payPeriod: _currentPayslip.payPeriod,
          employeeName: _currentPayslip.employeeName,
        );
        setState(() {
          _currentPayslip = Payslip(
            id: _currentPayslip.id,
            entryId: _currentPayslip.entryId,
            employeeId: _currentPayslip.employeeId,
            employeeName: _currentPayslip.employeeName,
            designation: _currentPayslip.designation,
            department: _currentPayslip.department,
            panNumber: _currentPayslip.panNumber,
            bankAccount: _currentPayslip.bankAccount,
            payPeriod: _currentPayslip.payPeriod,
            totalWorkingDays: _currentPayslip.totalWorkingDays,
            presentDays: _currentPayslip.presentDays,
            halfDays: _currentPayslip.halfDays,
            absentDays: _currentPayslip.absentDays,
            paidLeaveDays: _currentPayslip.paidLeaveDays,
            holidayDays: _currentPayslip.holidayDays,
            weeklyOffDays: _currentPayslip.weeklyOffDays,
            calendarDays: _currentPayslip.calendarDays,
            dailyRate: _currentPayslip.dailyRate,
            grossSalary: _currentPayslip.grossSalary,
            lopDays: _currentPayslip.lopDays,
            lopDeduction: _currentPayslip.lopDeduction,
            overtimeEnabled: _currentPayslip.overtimeEnabled,
            overtimeRate: _currentPayslip.overtimeRate,
            overtimeHours: _currentPayslip.overtimeHours,
            overtimeAmount: _currentPayslip.overtimeAmount,
            breakdown: _currentPayslip.breakdown,
            status: PayrollStatus.draft,
            generatedDate: _currentPayslip.generatedDate,
            adjustments: _currentPayslip.adjustments,
          );
        });
        if (mounted) {
          context.showToast(
            "${_currentPayslip.employeeName}'s payroll unlocked to Draft.",
            isWarning: true,
          );
        }
      } else {
        await _payrollService.finalizeEmployee(
          employeeId: _currentPayslip.employeeId,
          payPeriod: _currentPayslip.payPeriod,
          employeeName: _currentPayslip.employeeName,
        );
        setState(() {
          _currentPayslip = Payslip(
            id: _currentPayslip.id,
            entryId: _currentPayslip.entryId,
            employeeId: _currentPayslip.employeeId,
            employeeName: _currentPayslip.employeeName,
            designation: _currentPayslip.designation,
            department: _currentPayslip.department,
            panNumber: _currentPayslip.panNumber,
            bankAccount: _currentPayslip.bankAccount,
            payPeriod: _currentPayslip.payPeriod,
            totalWorkingDays: _currentPayslip.totalWorkingDays,
            presentDays: _currentPayslip.presentDays,
            halfDays: _currentPayslip.halfDays,
            absentDays: _currentPayslip.absentDays,
            paidLeaveDays: _currentPayslip.paidLeaveDays,
            holidayDays: _currentPayslip.holidayDays,
            weeklyOffDays: _currentPayslip.weeklyOffDays,
            calendarDays: _currentPayslip.calendarDays,
            dailyRate: _currentPayslip.dailyRate,
            grossSalary: _currentPayslip.grossSalary,
            lopDays: _currentPayslip.lopDays,
            lopDeduction: _currentPayslip.lopDeduction,
            overtimeEnabled: _currentPayslip.overtimeEnabled,
            overtimeRate: _currentPayslip.overtimeRate,
            overtimeHours: _currentPayslip.overtimeHours,
            overtimeAmount: _currentPayslip.overtimeAmount,
            breakdown: _currentPayslip.breakdown,
            status: PayrollStatus.finalized,
            generatedDate: _currentPayslip.generatedDate,
            adjustments: _currentPayslip.adjustments,
          );
        });
        if (mounted) {
          context.showToast(
            "${_currentPayslip.employeeName}'s payroll locked & finalized.",
            isSuccess: true,
          );
        }
      }
      widget.onStatusChanged?.call();
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: 'Action failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLocking = false);
    }
  }

  void _handleCopySummary() {
    final s = _currentPayslip;
    final summary = '''
PAYROLL SUMMARY - ${s.payPeriod}
Employee: ${s.employeeName} (${s.employeeId})
Role: ${s.designation} · ${s.department}
Status: ${s.status.label.toUpperCase()}

WORK & ATTENDANCE:
• Working Days: ${s.totalWorkingDays} days (Calendar: ${s.calendarDays})
• Present Days: ${s.presentDays} days
• LOP Days: ${s.lopDays.toStringAsFixed(1)} days
• Overtime: ${s.overtimeHours.toStringAsFixed(1)} hrs

FINANCIAL BREAKDOWN:
• Gross Monthly: ${s.formattedGross}
• Overtime Pay: ${s.formattedOvertimeAmount}
• LOP Deductions: ${s.formattedLopDeduction}
• NET TAKE-HOME: ${s.formattedNetPay}
• Bank Account: ${s.bankAccount}
• PAN: ${s.panNumber}
''';
    Clipboard.setData(ClipboardData(text: summary.trim()));
    context.showToast(
      'Payslip summary copied to clipboard',
      isSuccess: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Color _statusColor(PayrollStatus status) {
    switch (status) {
      case PayrollStatus.draft:
        return const Color(0xFFF59E0B);
      case PayrollStatus.processing:
        return const Color(0xFF3B82F6);
      case PayrollStatus.finalized:
        return const Color(0xFF10B981);
      case PayrollStatus.paid:
      case PayrollStatus.disbursed:
        return const Color(0xFF059669);
      case PayrollStatus.approved:
        return const Color(0xFF6366F1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isEmployee = authService.user?.isEmployee ?? false;
    final isAdmin = widget.isAdmin ?? !isEmployee;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _currentPayslip;
    final isLocked = s.status.isLocked;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 6, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.employeeName.isNotEmpty ? s.employeeName[0] : 'E',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4338CA),
                    ),
                  ),
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
                              s.employeeName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(s.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLocked)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: Icon(Icons.lock, size: 9, color: _statusColor(s.status)),
                                  ),
                                Text(
                                  s.status.label.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(s.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.employeeId} · ${s.designation} · ${s.department}',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pay Period: ${s.payPeriod}',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Net Pay Hero
                  _buildNetPayHero(isDark, s),

                  const SizedBox(height: 12),

                  // ── THINGS TO DO / QUICK ACTIONS ────────────────────────
                  _buildThingsToDoSection(context, isDark, isAdmin),

                  const SizedBox(height: 12),

                  // ── ATTENDANCE & WORK VERIFICATION CHECKLIST ────────────
                  _buildAttendanceVerificationChecklist(isDark, s),

                  const SizedBox(height: 12),

                  // ── SALARY BREAKDOWN ────────────────────────────────────
                  SalaryBreakdownCard(
                    breakdown: s.breakdown,
                    payslip: s,
                    isCompact: true,
                    showHeader: true,
                  ),

                  const SizedBox(height: 12),

                  // ── EMPLOYEE & BANK DETAILS ─────────────────────────────
                  _buildSection(
                    title: 'Employee & Bank Details',
                    icon: Icons.account_balance_outlined,
                    isDark: isDark,
                    child: Column(
                      children: [
                        _infoRow('Employee ID', s.employeeId, isDark),
                        _infoRow('Department', s.department, isDark),
                        _infoRow('Designation', s.designation, isDark),
                        _infoRow('Bank Account', s.bankAccount, isDark),
                        _infoRow('PAN Number', s.panNumber, isDark),
                        _infoRow('Pay Period', s.payPeriod, isDark),
                        _infoRow('Status', s.status.label, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Net Pay Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4338CA).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NET PAYABLE SALARY',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              s.formattedNetPay,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Gross: ${s.formattedGross}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Deductions: ${s.formattedDeductions}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Center(
                    child: Text(
                      'System-generated payroll statement • Mano Attendance HRMS',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky Contextual Bottom Actions Bar ────────────────────────
          _buildStickyBottomBar(isDark, isAdmin),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets: Things To Do / Quick Actions Hub
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildThingsToDoSection(BuildContext context, bool isDark, bool isAdmin) {
    final s = _currentPayslip;
    final isLocked = s.status.isLocked;

    // Stage subtitle
    String stageText = 'Step 1 of 3: Review & Lock';
    Color stageColor = const Color(0xFFF59E0B);
    String noteText = 'Review attendance days and salary deductions below, then Lock & Finalize this payroll.';

    if (s.status == PayrollStatus.paid || s.status == PayrollStatus.disbursed) {
      stageText = 'Step 3 of 3: Disbursed';
      stageColor = const Color(0xFF059669);
      noteText = 'Salary has been marked as disbursed to the employee account.';
    } else if (isLocked) {
      stageText = 'Step 2 of 3: Finalized & Locked';
      stageColor = const Color(0xFF10B981);
      noteText = 'Calculations are locked and finalized. Ready for bank payout and payslip distribution.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Stage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFF4338CA), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'THINGS TO DO / QUICK ACTIONS',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  stageText,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: stageColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Guidance Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    noteText,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Actions Grid
          Column(
            children: [
              // Row 1: Lock / Unlock & Download PDF
              Row(
                children: [
                  // Lock / Unlock Action
                  if (isAdmin)
                    Expanded(
                      child: _buildActionTile(
                        icon: isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        title: isLocked ? 'Unlock Payroll' : 'Lock & Finalize',
                        subtitle: isLocked ? 'Revert to Draft' : 'Secure numbers',
                        color: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                        isLoading: _isLocking,
                        isDark: isDark,
                        onTap: () => _handleToggleLock(isAdmin),
                      ),
                    ),
                  if (isAdmin) const SizedBox(width: 8),
                  // Download PDF
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.download_rounded,
                      title: 'Download PDF',
                      subtitle: 'Save to device',
                      color: const Color(0xFF059669),
                      isLoading: _isGeneratingPdf,
                      isDark: isDark,
                      onTap: _handleDownloadPdf,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 2: View / Preview PDF & Copy Summary
              Row(
                children: [
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Preview PDF',
                      subtitle: 'Open document',
                      color: const Color(0xFF2563EB),
                      isLoading: _isOpeningPdf,
                      isDark: isDark,
                      onTap: _handleOpenPdf,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionTile(
                      icon: Icons.copy_rounded,
                      title: 'Copy Summary',
                      subtitle: 'Share on WhatsApp',
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                      onTap: _handleCopySummary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets: Attendance & Work Verification Checklist
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAttendanceVerificationChecklist(bool isDark, Payslip s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.fact_check_outlined, color: Color(0xFF10B981), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ATTENDANCE & WORK VERIFICATION',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Rate: ₹${s.dailyRate.toStringAsFixed(0)}/day',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4338CA),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4x2 Grid of Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  label: 'Working Days',
                  value: '${s.totalWorkingDays}',
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFF4338CA),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'Present Days',
                  value: '${s.presentDays}',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'Half Days',
                  value: '${s.halfDays}',
                  icon: Icons.timelapse_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'Absent Days',
                  value: '${s.absentDays}',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  label: 'Paid Leaves',
                  value: '${s.paidLeaveDays}',
                  icon: Icons.beach_access_outlined,
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'Holidays/Off',
                  value: '${(s.holidayDays + s.weeklyOffDays).toInt()}',
                  icon: Icons.celebration_outlined,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'LOP Days',
                  value: s.lopDays > 0 ? '${s.lopDays.toStringAsFixed(1)}d' : '0d',
                  subtext: s.lopDeduction > 0 ? '-₹${s.lopDeduction.toStringAsFixed(0)}' : null,
                  icon: Icons.money_off_rounded,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricPill(
                  label: 'Overtime',
                  value: s.overtimeHours > 0 ? '${s.overtimeHours.toStringAsFixed(1)}h' : '0h',
                  subtext: s.overtimeAmount > 0 ? '+₹${s.overtimeAmount.toStringAsFixed(0)}' : null,
                  icon: Icons.more_time_rounded,
                  color: const Color(0xFF059669),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 7.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (subtext != null)
            Text(
              subtext,
              style: GoogleFonts.poppins(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets: Net Pay Hero
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNetPayHero(bool isDark, Payslip s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4338CA),
            Color(0xFF6366F1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET TAKE-HOME SALARY',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                s.formattedNetPay,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                'Gross: ${s.formattedGross}  •  Deductions: ${s.formattedDeductions}',
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  s.status.isLocked ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  s.status.label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets: Sticky Bottom Action Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStickyBottomBar(bool isDark, bool isAdmin) {
    final s = _currentPayslip;
    final isLocked = s.status.isLocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // If Draft & Admin: Primary Lock & Finalize button
            if (isAdmin && !isLocked) ...[
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isLocking ? null : () => _handleToggleLock(isAdmin),
                  icon: _isLocking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text(
                    _isLocking ? 'Finalizing...' : 'Lock & Finalize',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _handleDownloadPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF059669),
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    _isGeneratingPdf ? 'Saving...' : 'Download PDF',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF059669),
                    side: const BorderSide(color: Color(0xFF059669)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              // If Locked or Employee
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _handleDownloadPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    _isGeneratingPdf ? 'Generating PDF...' : 'Download Payslip PDF',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (isAdmin && isLocked) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isLocking ? null : () => _handleToggleLock(isAdmin),
                    icon: const Icon(Icons.lock_open_rounded, size: 14),
                    label: Text(
                      'Unlock',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF4338CA)),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
