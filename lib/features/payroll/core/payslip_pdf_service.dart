import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_application/features/payroll/core/payroll_model.dart';

// Currency formatter using "Rs." prefix (avoids ₹ glyph missing in embedded fonts)
String _fmtCurrency(double amount) {
  final formatted = NumberFormat('#,##,##0.00', 'en_IN').format(amount);
  return 'Rs. $formatted';
}

class PayslipPdfService {
  /// Generates a single-page PDF Payslip document matching Attendance-Web (PayslipService.js).
  /// Returns the absolute filepath of the generated PDF file.
  static Future<String> generateAndSavePayslipPdf(Payslip payslip) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#0969DA'); // Web Accent Blue
    final textColor = PdfColor.fromHex('#24292F');
    final secondaryTextColor = PdfColor.fromHex('#57606A');
    final lightBgColor = PdfColor.fromHex('#F6F8FA');
    final tableHeaderBg = PdfColor.fromHex('#EAEEF2');
    final borderColor = PdfColor.fromHex('#D0D7DE');
    final greenStatusColor = PdfColor.fromHex('#2DA44E');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "MANO TECHNOLOGIES",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Monthly Payroll Statement",
                        style: pw.TextStyle(fontSize: 9, color: secondaryTextColor),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Payslip for ${payslip.payPeriod}",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Status: ${payslip.status.label.toUpperCase()}",
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: greenStatusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 10),

              // 2. Employee Information Section
              pw.Text(
                "Employee Information",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow("Employee Code:", payslip.employeeId, textColor, secondaryTextColor),
                          pw.SizedBox(height: 5),
                          _buildInfoRow("Employee Name:", payslip.employeeName, textColor, secondaryTextColor),
                          pw.SizedBox(height: 5),
                          _buildInfoRow("Email Address:", "${payslip.employeeId.toLowerCase()}@mano.co.in", textColor, secondaryTextColor),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow("Department:", payslip.department, textColor, secondaryTextColor),
                          pw.SizedBox(height: 5),
                          _buildInfoRow("Designation:", payslip.designation, textColor, secondaryTextColor),
                          pw.SizedBox(height: 5),
                          _buildInfoRow("Payroll ID:", payslip.id, textColor, secondaryTextColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // 3. Attendance & Leave Summary Section
              pw.Text(
                "Attendance & Leave Summary",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 1),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: tableHeaderBg),
                    children: [
                      _buildHeaderCell("Present"),
                      _buildHeaderCell("Half Days"),
                      _buildHeaderCell("Absent"),
                      _buildHeaderCell("On Leave"),
                      _buildHeaderCell("Holidays"),
                      _buildHeaderCell("Week Offs"),
                      _buildHeaderCell("Overtime"),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildValueCell(payslip.presentDays.toStringAsFixed(2)),
                      _buildValueCell(payslip.halfDays.toStringAsFixed(2)),
                      _buildValueCell(payslip.absentDays.toStringAsFixed(2)),
                      _buildValueCell(payslip.paidLeaveDays.toStringAsFixed(2)),
                      _buildValueCell(payslip.holidayDays.toStringAsFixed(2)),
                      _buildValueCell(payslip.weeklyOffDays.toStringAsFixed(2)),
                      _buildValueCell("${payslip.overtimeHours.toStringAsFixed(1)} hrs"),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 14),

              // 4. Salary & Deductions Details Breakdown Table
              pw.Text(
                "Salary & Deductions Details",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 6),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // EARNINGS TABLE (Left side)
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: borderColor, width: 1),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            _buildHeaderCell("EARNINGS"),
                            _buildHeaderCell("AMOUNT", alignRight: true),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _buildValueCell("Gross Monthly Salary"),
                            _buildValueCell(_fmtCurrency(payslip.grossSalary), alignRight: true),
                          ],
                        ),
                        if (payslip.overtimeAmount > 0)
                          pw.TableRow(
                            children: [
                              _buildValueCell("Overtime Allowance (${payslip.overtimeHours} hrs)"),
                              _buildValueCell(_fmtCurrency(payslip.overtimeAmount), alignRight: true),
                            ],
                          ),
                        ...payslip.adjustments
                            .where((a) => a.type == 'addition')
                            .map((a) => pw.TableRow(
                                  children: [
                                    _buildValueCell(a.label),
                                    _buildValueCell(_fmtCurrency(a.amount), alignRight: true),
                                  ],
                                )),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  // DEDUCTIONS TABLE (Right side)
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: borderColor, width: 1),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            _buildHeaderCell("DEDUCTIONS"),
                            _buildHeaderCell("AMOUNT", alignRight: true),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            _buildValueCell("Loss of Pay (LOP) Deduction"),
                            _buildValueCell(_fmtCurrency(payslip.lopDeduction), alignRight: true),
                          ],
                        ),
                        ...payslip.adjustments
                            .where((a) => a.type == 'deduction')
                            .map((a) => pw.TableRow(
                                  children: [
                                    _buildValueCell(a.label),
                                    _buildValueCell(_fmtCurrency(a.amount), alignRight: true),
                                  ],
                                )),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // 5. Net Salary Highlight Block
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "NET PAYABLE SALARY",
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          numberToWords(payslip.netPay),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      _fmtCurrency(payslip.netPay),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),
              pw.Text(
                "* Deductions calculated based on ${payslip.lopDays.toStringAsFixed(1)} LOP (Loss of Pay) days in ${payslip.payPeriod}.",
                style: pw.TextStyle(fontSize: 8, color: secondaryTextColor, fontStyle: pw.FontStyle.italic),
              ),

              pw.Spacer(),

              // 6. Footer Section
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  "This is a computer-generated payslip and does not require a physical signature.",
                  style: pw.TextStyle(fontSize: 8, color: secondaryTextColor),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  "Powered by MANO Attendance HRMS Platform v1.0",
                  style: pw.TextStyle(fontSize: 8, color: secondaryTextColor),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save File
    final dir = await getApplicationDocumentsDirectory();
    final fileName = "Payslip_${payslip.employeeId}_${payslip.payPeriod.replaceAll(' ', '_')}.pdf";
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(await pdf.save());

    debugPrint("Payslip PDF saved to: ${file.path}");
    return file.path;
  }

  /// Generates a single-page PDF Payslip document matching Attendance-Web PayslipModal.jsx exactly.
  static Future<String> generateAndSaveItemizedPayslipPdf(ItemizedPayslip payslip, {String? payPeriod}) async {
    final pdf = pw.Document();

    final borderGrey = PdfColor.fromHex('#334155');
    final textDark = PdfColor.fromHex('#0F172A');
    final secondaryText = PdfColor.fromHex('#475569');
    final bgLightSlate = PdfColor.fromHex('#F1F5F9');
    final bgSlate50 = PdfColor.fromHex('#F8FAFC');
    final blueHighlightBg = PdfColor.fromHex('#DBEAFE');
    final redDeduction = PdfColor.fromHex('#DC2626');

    final period = payPeriod ?? (payslip.periodStart != null ? payslip.periodStart! : 'Payroll Period');
    final companyName = payslip.orgName.isNotEmpty ? payslip.orgName : 'MANO TECHNOLOGIES';
    final payableDays = (payslip.calendarDays - payslip.absentDays).clamp(0, payslip.calendarDays).toInt();

    // Prepare paired earnings and deductions
    final earnings = payslip.earnings;
    final deductions = payslip.deductions;
    final maxRows = earnings.length > deductions.length ? earnings.length : deductions.length;
    final rowCount = maxRows > 0 ? maxRows : 1;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderGrey, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Header Section
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: borderGrey, width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            "MANO",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          pw.Text(
                            "WORKFORCE PLATFORM",
                            style: pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: borderGrey, width: 1)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "Payslip for the month of $period",
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: bgLightSlate,
                    border: pw.Border(bottom: pw.BorderSide(color: borderGrey, width: 1)),
                  ),
                  child: pw.Text(
                    "EMPLOYEE PAY SUMMARY",
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                ),

                // 2. Employee Information Grid Table
                pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(color: borderGrey, width: 1),
                    horizontalInside: pw.BorderSide(color: borderGrey, width: 1),
                    verticalInside: pw.BorderSide(color: borderGrey, width: 1),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.9),
                    1: pw.FlexColumnWidth(3.1),
                    2: pw.FlexColumnWidth(1.9),
                    3: pw.FlexColumnWidth(3.1),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        _buildPdfCell("Employee Name", isHeader: true, bg: bgSlate50),
                        _buildPdfCell(payslip.employeeName, isBold: true),
                        _buildPdfCell("Department", isHeader: true, bg: bgSlate50),
                        _buildPdfCell(payslip.department),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell("Employee ID", isHeader: true, bg: bgSlate50),
                        _buildPdfCell(payslip.employeeCode.isNotEmpty ? payslip.employeeCode : "EMP-${payslip.employeeId}", isBold: true),
                        _buildPdfCell("Days Worked", isHeader: true, bg: bgSlate50),
                        _buildPdfCell("$payableDays", isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell("Designation", isHeader: true, bg: bgSlate50),
                        _buildPdfCell(payslip.designation),
                        _buildPdfCell("Pay Date", isHeader: true, bg: bgSlate50),
                        _buildPdfCell(payslip.paidAt ?? period),
                      ],
                    ),
                  ],
                ),

                // 3. Main Payroll Calculation Table (35% / 15% / 35% / 15%)
                pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(color: borderGrey, width: 1),
                    horizontalInside: pw.BorderSide(color: borderGrey, width: 1),
                    verticalInside: pw.BorderSide(color: borderGrey, width: 1),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3.5),
                    1: pw.FlexColumnWidth(1.5),
                    2: pw.FlexColumnWidth(3.5),
                    3: pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgLightSlate),
                      children: [
                        _buildPdfCell("EARNINGS", isHeader: true, isBold: true),
                        _buildPdfCell("AMOUNT", isHeader: true, isBold: true, alignRight: true),
                        _buildPdfCell("PARTICULARS", isHeader: true, isBold: true),
                        _buildPdfCell("DEDUCTIONS", isHeader: true, isBold: true, alignRight: true),
                      ],
                    ),
                    // Rows
                    ...List.generate(rowCount, (idx) {
                      final earn = idx < earnings.length ? earnings[idx] : null;
                      final ded = idx < deductions.length ? deductions[idx] : null;
                      return pw.TableRow(
                        children: [
                          _buildPdfCell(earn?.name ?? " "),
                          _buildPdfCell(earn != null ? _fmtCurrency(earn.amount) : " ", isBold: true, alignRight: true),
                          _buildPdfCell(ded?.name ?? " "),
                          _buildPdfCell(ded != null ? _fmtCurrency(ded.amount) : " ", isBold: true, alignRight: true, textColor: redDeduction),
                        ],
                      );
                    }),
                    // Subtotal
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgSlate50),
                      children: [
                        _buildPdfCell("Gross Earnings", isBold: true),
                        _buildPdfCell(_fmtCurrency(payslip.grossPay), isBold: true, alignRight: true),
                        _buildPdfCell("Total Deductions", isBold: true),
                        _buildPdfCell(_fmtCurrency(payslip.totalDeductions), isBold: true, alignRight: true, textColor: redDeduction),
                      ],
                    ),
                  ],
                ),

                // 4. NetPay Calculation Summary Table (85% / 15%)
                pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(color: borderGrey, width: 1),
                    horizontalInside: pw.BorderSide(color: borderGrey, width: 1),
                    verticalInside: pw.BorderSide(color: borderGrey, width: 1),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(8.5),
                    1: pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: bgLightSlate),
                      children: [
                        _buildPdfCell("NETPAY CALCULATION SUMMARY", isHeader: true, isBold: true),
                        _buildPdfCell("AMOUNT", isHeader: true, isBold: true, alignRight: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell("Gross Earnings"),
                        _buildPdfCell(_fmtCurrency(payslip.grossPay), isBold: true, alignRight: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildPdfCell("Total Deductions"),
                        _buildPdfCell("- ${_fmtCurrency(payslip.totalDeductions)}", isBold: true, alignRight: true, textColor: redDeduction),
                      ],
                    ),
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: blueHighlightBg),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: pw.Text(
                            "TOTAL NET PAYABLE",
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: pw.Text(
                            _fmtCurrency(payslip.netPay),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: textDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 5. Words & Formula Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: borderGrey, width: 1)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Total Net Payable: ${_fmtCurrency(payslip.netPay)} (${numberToWords(payslip.netPay)})",
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Total Net Payable = Gross Earnings - Total Deductions + Total Adjustments",
                        style: pw.TextStyle(fontSize: 7.5, color: secondaryText),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // 6. Signatures Block
                pw.Container(
                  height: 55,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  alignment: pw.Alignment.bottomCenter,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 140,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 1)),
                            ),
                            padding: const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(
                              "Employee Signature",
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Container(
                            width: 140,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 1)),
                            ),
                            padding: const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(
                              "Authorized Signatory",
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 7. Disclaimer Footer
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: borderGrey, width: 1)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "This is a system-generated payslip generated via MANO Attendance Platform. L.O.P. Days: ${payslip.absentDays.toInt()}",
                    style: pw.TextStyle(fontSize: 7.5, color: secondaryText),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = "Payslip_${payslip.employeeId}_${period.replaceAll(' ', '_')}.pdf";
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(await pdf.save());

    debugPrint("Itemized Payslip PDF saved to: ${file.path}");
    return file.path;
  }

  static pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    bool alignRight = false,
    PdfColor? bg,
    PdfColor? textColor,
  }) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 8,
          fontWeight: (isBold || isHeader) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? (isHeader ? PdfColor.fromHex('#475569') : PdfColor.fromHex('#0F172A')),
        ),
      ),
    );
  }

  /// Opens the generated PDF using open_filex
  static Future<void> openPayslipPdf(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        debugPrint("Could not open PDF file: ${result.message}");
      }
    } catch (e) {
      debugPrint("Error opening PDF file: $e");
    }
  }

  static pw.Widget _buildInfoRow(String label, String value, PdfColor textColor, PdfColor labelColor) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 95,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: labelColor, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 9, color: textColor, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String title, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        title,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
      ),
    );
  }

  static pw.Widget _buildValueCell(String content, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        content,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 8, color: PdfColors.black),
      ),
    );
  }
}

// [mod:2026-02-25T11:30:00+05:30]

// [rev:2026-08-25T11:00:00+05:30]
