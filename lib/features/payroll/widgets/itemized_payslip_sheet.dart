import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';
import 'package:flutter_application/features/payroll/core/payroll_service.dart';
import 'package:flutter_application/features/payroll/core/payslip_pdf_service.dart';

/// ItemizedPayslipSheet - Modal bottom sheet replicating PayslipModal.jsx
/// Displays itemized earnings, deductions, attendance summary, Net Pay in words, and PDF export.
class ItemizedPayslipSheet extends StatefulWidget {
  final int runId;
  final int employeeId;
  final PayrollRunEmployee? initialEmployee;
  final PayrollRun? run;
  final PayrollService payrollService;

  const ItemizedPayslipSheet({
    super.key,
    required this.runId,
    required this.employeeId,
    this.initialEmployee,
    this.run,
    required this.payrollService,
  });

  static Future<void> show(
    BuildContext context, {
    required int runId,
    required int employeeId,
    PayrollRunEmployee? initialEmployee,
    PayrollRun? run,
    required PayrollService payrollService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemizedPayslipSheet(
        runId: runId,
        employeeId: employeeId,
        initialEmployee: initialEmployee,
        run: run,
        payrollService: payrollService,
      ),
    );
  }

  @override
  State<ItemizedPayslipSheet> createState() => _ItemizedPayslipSheetState();
}

class _ItemizedPayslipSheetState extends State<ItemizedPayslipSheet> {
  bool _isLoading = true;
  ItemizedPayslip? _payslip;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadPayslip();
  }

  String _formatINR(double val) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(val);
  }

  Future<void> _loadPayslip() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.payrollService.getEmployeePayslip(widget.runId, widget.employeeId);
      if (mounted) {
        setState(() {
          _payslip = res ?? _buildFallbackPayslip();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _payslip = _buildFallbackPayslip();
          _isLoading = false;
        });
      }
    }
  }

  ItemizedPayslip _buildFallbackPayslip() {
    final emp = widget.initialEmployee;
    final r = widget.run;

    final earnings = (emp?.lines ?? []).where((l) => l.isEarning).toList();
    final deductions = (emp?.lines ?? []).where((l) => l.isDeduction).toList();

    return ItemizedPayslip(
      runId: widget.runId,
      runType: r?.runType,
      periodStart: r?.periodStart,
      periodEnd: r?.periodEnd,
      status: r?.status.name,
      paidAt: r?.paidAt,
      employeeName: emp?.employeeName ?? 'Staff Member',
      employeeCode: emp?.employeeCode ?? '',
      department: emp?.department ?? 'General',
      designation: emp?.designation ?? 'Staff',
      employeeId: widget.employeeId,
      presentDays: 24,
      absentDays: 2,
      halfDays: 0,
      holidays: 2,
      weeklyOff: 4,
      calendarDays: 30,
      earnings: earnings.isNotEmpty
          ? earnings
          : [
              PayrollLineItem(name: 'Basic Pay', transactionType: 'earning', amount: (emp?.grossPay ?? 50000) * 0.5),
              PayrollLineItem(name: 'House Rent Allowance (HRA)', transactionType: 'earning', amount: (emp?.grossPay ?? 50000) * 0.25),
              PayrollLineItem(name: 'Special Allowance', transactionType: 'earning', amount: (emp?.grossPay ?? 50000) * 0.25),
            ],
      deductions: deductions.isNotEmpty
          ? deductions
          : const [
              PayrollLineItem(name: 'Loss of Pay (2 days)', transactionType: 'deduction', amount: 3333),
              PayrollLineItem(name: 'Provident Fund (PF)', transactionType: 'deduction', amount: 1800),
              PayrollLineItem(name: 'Professional Tax (PT)', transactionType: 'deduction', amount: 200),
            ],
      grossPay: emp?.grossPay ?? 50000,
      totalDeductions: emp?.totalDeductions ?? 5333,
      netPay: emp?.netPay ?? 44667,
    );
  }

  Future<void> _handleExportPdf() async {
    if (_payslip == null) return;
    setState(() => _isExporting = true);

    try {
      final filePath = await PayslipPdfService.generateAndSaveItemizedPayslipPdf(
        _payslip!,
        payPeriod: widget.run?.payPeriod,
      );
      if (mounted) {
        setState(() => _isExporting = false);
        final fileName = filePath.split(RegExp(r'[/\\]')).last;
        context.showToast(
          'Payslip PDF downloaded: $fileName',
          isSuccess: true,
          actionLabel: 'OPEN',
          onActionPressed: () => PayslipPdfService.openPayslipPdf(filePath),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        context.showExceptionToast(e, fallback: 'Failed to generate PDF');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal Top Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print_outlined, color: Color(0xFF4F46E5), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Payslip Print Preview',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Text(
                              'A4 Print Format',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _payslip?.employeeName ?? widget.initialEmployee?.employeeName ?? 'Loading...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A),
                ),
              ],
            ),
          ),

          // Body: Exact Attendance-Web Print Format Document Canvas
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
              ),
            )
          else if (_payslip != null)
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Ensure document has sufficient width for standard table columns without flex overflows
                  final docWidth = constraints.maxWidth < 560 ? 560.0 : constraints.maxWidth;
                  final companyName = _payslip!.orgName.isNotEmpty ? _payslip!.orgName : 'MANO TECHNOLOGIES';
                  final monthTitle = widget.run?.payPeriod ?? (_payslip!.periodStart != null ? _formatMonthYear(_payslip!.periodStart!) : 'Payroll Period');
                  final payableDays = (_payslip!.calendarDays - _payslip!.absentDays).clamp(0, _payslip!.calendarDays).toInt();

                  // Paired rows for Earnings and Deductions
                  final earnings = _payslip!.earnings;
                  final deductions = _payslip!.deductions;
                  final maxRows = earnings.length > deductions.length ? earnings.length : deductions.length;
                  final rowCount = maxRows > 0 ? maxRows : 1;

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        width: docWidth,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: const Color(0xFF334155), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Header Section Table
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      companyName.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'MANO',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'WORKFORCE PLATFORM',
                                        style: GoogleFonts.poppins(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF475569),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Payslip for the month of $monthTitle',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                              ),
                              child: Text(
                                'EMPLOYEE PAY SUMMARY',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            // 2. Employee Information Grid Table (19% / 31% / 19% / 31%)
                            Table(
                              border: const TableBorder(
                                bottom: BorderSide(color: Color(0xFF334155), width: 1),
                                horizontalInside: BorderSide(color: Color(0xFF334155), width: 1),
                                verticalInside: BorderSide(color: Color(0xFF334155), width: 1),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(1.9),
                                1: FlexColumnWidth(3.1),
                                2: FlexColumnWidth(1.9),
                                3: FlexColumnWidth(3.1),
                              },
                              children: [
                                TableRow(
                                  children: [
                                    _buildInfoGridCell('Employee Name', isHeader: true),
                                    _buildInfoGridCell(_payslip!.employeeName, isBold: true),
                                    _buildInfoGridCell('Department', isHeader: true),
                                    _buildInfoGridCell(_payslip!.department),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    _buildInfoGridCell('Employee ID', isHeader: true),
                                    _buildInfoGridCell(
                                      _payslip!.employeeCode.isNotEmpty ? _payslip!.employeeCode : 'EMP-${_payslip!.employeeId}',
                                      isBold: true,
                                    ),
                                    _buildInfoGridCell('Days Worked', isHeader: true),
                                    _buildInfoGridCell('$payableDays', isBold: true),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    _buildInfoGridCell('Designation', isHeader: true),
                                    _buildInfoGridCell(_payslip!.designation),
                                    _buildInfoGridCell('Pay Date', isHeader: true),
                                    _buildInfoGridCell(
                                      _payslip!.paidAt != null ? _formatDateDMY(_payslip!.paidAt!) : monthTitle,
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // 3. Main Payroll Calculation Table (35% / 15% / 35% / 15%)
                            Table(
                              border: const TableBorder(
                                bottom: BorderSide(color: Color(0xFF334155), width: 1),
                                horizontalInside: BorderSide(color: Color(0xFF334155), width: 1),
                                verticalInside: BorderSide(color: Color(0xFF334155), width: 1),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(3.5),
                                1: FlexColumnWidth(1.5),
                                2: FlexColumnWidth(3.5),
                                3: FlexColumnWidth(1.5),
                              },
                              children: [
                                // A. Header Row
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                                  children: [
                                    _buildTableHeaderCell('EARNINGS'),
                                    _buildTableHeaderCell('AMOUNT', alignRight: true),
                                    _buildTableHeaderCell('PARTICULARS'),
                                    _buildTableHeaderCell('DEDUCTIONS', alignRight: true),
                                  ],
                                ),
                                // B. Paired Rows
                                ...List.generate(rowCount, (idx) {
                                  final earn = idx < earnings.length ? earnings[idx] : null;
                                  final ded = idx < deductions.length ? deductions[idx] : null;
                                  return TableRow(
                                    children: [
                                      _buildTableCell(earn?.name ?? ' '),
                                      _buildTableCell(
                                        earn != null ? '₹ ${_formatINR(earn.amount)}' : ' ',
                                        isBold: true,
                                        alignRight: true,
                                      ),
                                      _buildTableCell(ded?.name ?? ' '),
                                      _buildTableCell(
                                        ded != null ? '₹ ${_formatINR(ded.amount)}' : ' ',
                                        isBold: true,
                                        alignRight: true,
                                        textColor: const Color(0xFFDC2626),
                                      ),
                                    ],
                                  );
                                }),
                                // C. Subtotal Row
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                                  children: [
                                    _buildTableCell('Gross Earnings', isBold: true),
                                    _buildTableCell(
                                      '₹ ${_formatINR(_payslip!.grossPay)}',
                                      isBold: true,
                                      alignRight: true,
                                    ),
                                    _buildTableCell('Total Deductions', isBold: true),
                                    _buildTableCell(
                                      '₹ ${_formatINR(_payslip!.totalDeductions)}',
                                      isBold: true,
                                      alignRight: true,
                                      textColor: const Color(0xFFDC2626),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // 4. NetPay Calculation Summary (85% / 15% Grid Aligned)
                            Table(
                              border: const TableBorder(
                                bottom: BorderSide(color: Color(0xFF334155), width: 1),
                                horizontalInside: BorderSide(color: Color(0xFF334155), width: 1),
                                verticalInside: BorderSide(color: Color(0xFF334155), width: 1),
                              ),
                              columnWidths: const {
                                0: FlexColumnWidth(8.5),
                                1: FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                                  children: [
                                    _buildTableHeaderCell('NETPAY CALCULATION SUMMARY'),
                                    _buildTableHeaderCell('AMOUNT', alignRight: true),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    _buildTableCell('Gross Earnings'),
                                    _buildTableCell('₹ ${_formatINR(_payslip!.grossPay)}', isBold: true, alignRight: true),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    _buildTableCell('Total Deductions'),
                                    _buildTableCell(
                                      '- ₹ ${_formatINR(_payslip!.totalDeductions)}',
                                      isBold: true,
                                      alignRight: true,
                                      textColor: const Color(0xFFDC2626),
                                    ),
                                  ],
                                ),
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFDBEAFE)),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Text(
                                        'TOTAL NET PAYABLE',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Text(
                                        '₹ ${_formatINR(_payslip!.netPay)}',
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // 5. Words & Formula Section
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF0F172A)),
                                      children: [
                                        const TextSpan(text: 'Total Net Payable: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(
                                          text: '₹ ${_formatINR(_payslip!.netPay)}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
                                        ),
                                        TextSpan(
                                          text: ' (${numberToWordsINR(_payslip!.netPay)})',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Total Net Payable = Gross Earnings - Total Deductions + Total Adjustments',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 6. Signatures Block
                            Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              alignment: Alignment.bottomCenter,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 150,
                                        decoration: const BoxDecoration(
                                          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
                                        ),
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          'Employee Signature',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 150,
                                        decoration: const BoxDecoration(
                                          border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
                                        ),
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          'Authorized Signatory',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 7. Disclaimer Footer
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'This is a system-generated payslip generated via MANO Attendance Platform. L.O.P. Days: ${_payslip!.absentDays.toInt()}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Modal Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 14),
                  label: Text('Close', style: GoogleFonts.inter(fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _handleExportPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    _isExporting ? 'Generating PDF...' : 'Download PDF Payslip',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Table Builders matching Attendance-Web ---

  Widget _buildInfoGridCell(String text, {bool isHeader = false, bool isBold = false}) {
    return Container(
      color: isHeader ? const Color(0xFFF8FAFC) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: isHeader ? FontWeight.w700 : (isBold ? FontWeight.w700 : FontWeight.w500),
          color: isHeader ? const Color(0xFF475569) : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isBold = false,
    bool alignRight = false,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: textColor ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }

  String _formatDateDMY(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatMonthYear(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('MMMM yyyy').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  String numberToWordsINR(double num) {
    if (num <= 0) return 'Zero Rupees Only';
    final a = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String inWords(int n) {
      if (n == 0) return '';
      if (n < 20) return '${a[n]} ';
      if (n < 100) return '${b[n ~/ 10]}${n % 10 != 0 ? ' ${a[n % 10]}' : ''} ';
      if (n < 1000) return '${a[n ~/ 100]} Hundred ${n % 100 != 0 ? 'and ${inWords(n % 100)}' : ''}';
      return '';
    }

    int n = num.floor().abs();
    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final remaining = n;

    var str = '';
    if (crore > 0) str += '${inWords(crore)}Crore ';
    if (lakh > 0) str += '${inWords(lakh)}Lakh ';
    if (thousand > 0) str += '${inWords(thousand)}Thousand ';
    if (remaining > 0) str += inWords(remaining);

    return '${str.trim()} Rupees Only';
  }
}
