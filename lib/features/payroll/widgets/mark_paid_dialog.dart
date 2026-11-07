import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// MarkPaidDialog - Modal dialog replicating MarkPaidModal.jsx
/// Confirms bank disbursement and marks payroll run as paid.
class MarkPaidDialog extends StatefulWidget {
  final PayrollRun run;
  final PayrollService payrollService;
  final ValueChanged<PayrollRun> onPaidConfirmed;

  const MarkPaidDialog({
    super.key,
    required this.run,
    required this.payrollService,
    required this.onPaidConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required PayrollRun run,
    required PayrollService payrollService,
    required ValueChanged<PayrollRun> onPaidConfirmed,
  }) {
    return showDialog(
      context: context,
      builder: (context) => MarkPaidDialog(
        run: run,
        payrollService: payrollService,
        onPaidConfirmed: onPaidConfirmed,
      ),
    );
  }

  @override
  State<MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<MarkPaidDialog> {
  DateTime _disbursementDate = DateTime.now();
  String _paymentMethod = 'bank_transfer';
  final TextEditingController _refController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  String _formatINR(double val) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(val);
  }

  Future<void> _handleConfirm() async {
    setState(() => _isSubmitting = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_disbursementDate);

    try {
      final updated = await widget.payrollService.markRunAsPaid(
        widget.run.id,
        paidAt: dateStr,
        paymentMode: _paymentMethod,
        transactionRef: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        final paidRun = updated ?? PayrollRun(
          id: widget.run.id,
          batchName: widget.run.batchName,
          runType: widget.run.runType,
          payPeriod: widget.run.payPeriod,
          periodStart: widget.run.periodStart,
          periodEnd: widget.run.periodEnd,
          status: PayrollStatus.paid,
          totalEmployees: widget.run.totalEmployees,
          totalGrossPayout: widget.run.totalGrossPayout,
          totalDeductions: widget.run.totalDeductions,
          totalNetPayout: widget.run.totalNetPayout,
          processedDate: widget.run.processedDate,
          paidAt: dateStr,
          isLocked: true,
          summary: widget.run.summary,
          employees: widget.run.employees,
        );
        widget.onPaidConfirmed(paidRun);
        context.showToast('Payroll run marked as Paid & Disbursed!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        context.showExceptionToast(e, fallback: 'Failed to record disbursement');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Confirm Salary Disbursement',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Record payouts and release employee payslips',
                          style: GoogleFonts.inter(fontSize: 11, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Payout Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PAYOUT TO DISBURSE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_formatINR(widget.run.totalNetPayout)}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'Across ${widget.run.totalEmployees} staff members in Run #${widget.run.id}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const Icon(Icons.check_circle, size: 28, color: Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Disbursement Date
              Text(
                'Disbursement Date',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _disbursementDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _disbursementDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMMM yyyy').format(_disbursementDate),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Channel Selector
              Text(
                'Disbursement Channel',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildChannelOption('bank_transfer', 'Bank Transfer', 'NEFT / RTGS'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChannelOption('cheque', 'Cheque', 'Corporate'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChannelOption('cash', 'Cash', 'Counter'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reference Note
              Text(
                'Reference / UTR Note (Optional)',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _refController,
                decoration: InputDecoration(
                  hintText: 'e.g. UTR-982348234 or HDFC Batch #44',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      _isSubmitting ? 'Recording Payout...' : 'Confirm Disbursement',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelOption(String id, String label, String sub) {
    final isSel = _paymentMethod == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _paymentMethod = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF0D1117) : const Color(0xFFF9FAFB)),
          border: Border.all(
            color: isSel
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE)),
            width: isSel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                color: isSel ? const Color(0xFF4F46E5) : null,
              ),
            ),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
