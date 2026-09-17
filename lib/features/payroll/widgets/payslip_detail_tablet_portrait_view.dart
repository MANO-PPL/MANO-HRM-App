import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/features/payroll/core/payslip_pdf_service.dart';
import 'package:flutter_application/features/payroll/widgets/salary_breakdown_card.dart';

class PayslipDetailScreenTablet extends StatefulWidget {
  final Payslip payslip;
  final PayrollService? payrollService;
  final bool? isAdmin;
  final VoidCallback? onStatusChanged;

  const PayslipDetailScreenTablet({
    super.key,
    required this.payslip,
    this.payrollService,
    this.isAdmin,
    this.onStatusChanged,
  });

  @override
  State<PayslipDetailScreenTablet> createState() => _PayslipDetailScreenTabletState();
}

class _PayslipDetailScreenTabletState extends State<PayslipDetailScreenTablet> {
  late Payslip _currentPayslip;
  late PayrollService _payrollService;
  bool _isGeneratingPdf = false;
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

  Future<void> _handleDownloadPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final path = await PayslipPdfService.generateAndSavePayslipPdf(_currentPayslip);
      _lastGeneratedPdfPath = path;
      if (mounted) {
        context.showToast(
          'PDF Payslip saved: ${path.split('/').last}',
          isSuccess: true,
          actionLabel: 'OPEN',
          onActionPressed: () => PayslipPdfService.openPayslipPdf(path),
        );
      }
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: 'Failed to generate PDF');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleOpenPdf() async {
    try {
      String path = _lastGeneratedPdfPath ?? '';
      if (path.isEmpty) {
        path = await PayslipPdfService.generateAndSavePayslipPdf(_currentPayslip);
        _lastGeneratedPdfPath = path;
      }
      await PayslipPdfService.openPayslipPdf(path);
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: 'Failed to open PDF');
    }
  }

  Future<void> _handleToggleLock(bool isAdmin) async {
    if (!isAdmin || _isLocking) return;
    final isLocked = _currentPayslip.status.isLocked;
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
      }

      widget.onStatusChanged?.call();

      if (mounted) {
        context.showToast(
          isLocked ? 'Payslip unlocked to Draft' : 'Payslip locked and finalized',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) context.showExceptionToast(e, fallback: 'Failed to update lock status');
    } finally {
      if (mounted) setState(() => _isLocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final isAdmin = widget.isAdmin ?? (authService.user?.isAdmin ?? false);
    final isLocked = _currentPayslip.status.isLocked;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Salary Slip - ${_currentPayslip.payPeriod}",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4338CA).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock, size: 11, color: Color(0xFF4338CA)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "LOCKED",
                                    style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_currentPayslip.employeeName} (${_currentPayslip.employeeId}) • ${_currentPayslip.department} • ${_currentPayslip.designation}",
                        style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: "Close",
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Metadata & Attendance Metrics Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildMetaTile('Present Days', '${(_currentPayslip.presentDays as num).toStringAsFixed(0)}/${_currentPayslip.totalWorkingDays}', isDark),
                  _buildMetaTile('LOP Days', '${_currentPayslip.lopDays.toStringAsFixed(0)} d', isDark),
                  _buildMetaTile('Overtime', '${_currentPayslip.overtimeHours}h', isDark),
                  _buildMetaTile('PAN', _currentPayslip.panNumber.isEmpty ? '—' : _currentPayslip.panNumber, isDark),
                  _buildMetaTile('Bank A/C', _currentPayslip.bankAccount.isEmpty ? '—' : _currentPayslip.bankAccount, isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Scrollable Salary Breakdown
            Expanded(
              child: SingleChildScrollView(
                child: SalaryBreakdownCard(
                  breakdown: _currentPayslip.breakdown,
                  payslip: _currentPayslip,
                  isCompact: false,
                  showHeader: true,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Actions Footer
            Row(
              children: [
                if (isAdmin) ...[
                  OutlinedButton.icon(
                    onPressed: _isLocking ? null : () => _handleToggleLock(isAdmin),
                    icon: _isLocking
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(isLocked ? Icons.lock_open : Icons.lock, size: 16),
                    label: Text(
                      isLocked ? "Unlock Payslip" : "Lock Payslip",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA),
                      side: BorderSide(color: isLocked ? const Color(0xFFF59E0B) : const Color(0xFF4338CA)),
                    ),
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _handleOpenPdf,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text("View PDF", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _handleDownloadPdf,
                  icon: _isGeneratingPdf
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    _isGeneratingPdf ? "Generating..." : "Download PDF",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaTile(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
