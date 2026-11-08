import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/reports/core/report_models.dart';

class PdfPrintPreviewWidget extends StatelessWidget {
  final List<String> columns;
  final List<List<dynamic>> rows;
  final String reportTitle;
  final DateTime selectedDate;
  final bool useDateRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final ReportSummaryStats? summary;
  final String companyName;
  final VoidCallback onDownloadPdf;
  final bool isDownloading;
  final String? downloadedFilePath;
  final ValueChanged<String>? onOpenFile;

  const PdfPrintPreviewWidget({
    super.key,
    required this.columns,
    required this.rows,
    required this.reportTitle,
    required this.selectedDate,
    this.useDateRange = false,
    this.startDate,
    this.endDate,
    this.summary,
    this.companyName = 'MANO TECHNOLOGIES',
    required this.onDownloadPdf,
    this.isDownloading = false,
    this.downloadedFilePath,
    this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formattedPeriod = useDateRange && startDate != null && endDate != null
        ? "${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}"
        : DateFormat('MMMM yyyy').format(selectedDate);

    final cleanTitle = reportTitle
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top Print Preview Action Ribbon ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PDF Print Mode Preview",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "A4 Landscape Sheet • Formatted for standard legal print & filing",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Open Downloaded File directly (if ready)
              if (downloadedFilePath != null && onOpenFile != null) ...[
                OutlinedButton.icon(
                  onPressed: () => onOpenFile!(downloadedFilePath!),
                  icon: const Icon(Icons.folder_open_rounded, size: 15),
                  label: Text(
                    "Open File",
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Download / Print PDF Button
              ElevatedButton.icon(
                onPressed: isDownloading ? null : onDownloadPdf,
                icon: isDownloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  isDownloading ? "Generating..." : "Download PDF",
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── A4 Print Document Canvas ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF090D13) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                width: 960,
                decoration: BoxDecoration(
                  color: Colors.white, // Authentic White Paper
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Company Letterhead Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.business_rounded, color: Colors.white, size: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  companyName.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  "Automated Attendance & Workforce Management System",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2F6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                "OFFICIAL RECORD",
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                    const SizedBox(height: 12),

                    // 2. Report Title & Filter Context Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanTitle.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Period: $formattedPeriod • Total Records: ${rows.length}",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.print_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Text(
                                "Page 1 of 1",
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. KPI Summary Strip (if summary provided)
                    if (summary != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildKpiItem("PRESENT", "${summary!.present}", const Color(0xFF16A34A)),
                            _buildVerticalSep(),
                            _buildKpiItem("ABSENT", "${summary!.absent}", const Color(0xFFDC2626)),
                            _buildVerticalSep(),
                            _buildKpiItem("LEAVE", "${summary!.leave}", const Color(0xFFEAB308)),
                            _buildVerticalSep(),
                            _buildKpiItem("HALF DAY", "${summary!.halfDay}", const Color(0xFFF97316)),
                            _buildVerticalSep(),
                            _buildKpiItem("LATE", "${summary!.lateCount}", const Color(0xFF8B5CF6)),
                            if (summary!.overtimeHours > 0) ...[
                              _buildVerticalSep(),
                              _buildKpiItem("OVERTIME", "${summary!.overtimeHours.toStringAsFixed(1)}h", const Color(0xFF0284C7)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. Formal Print Table
                    if (columns.isNotEmpty && rows.isNotEmpty)
                      Table(
                        border: TableBorder.all(
                          color: const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        columnWidths: _computeColumnWidths(columns),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          // Header Row
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                            ),
                            children: columns.map((col) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                child: Text(
                                  col.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                  textAlign: _alignForColumn(col),
                                ),
                              );
                            }).toList(),
                          ),
                          // Data Rows
                          ...rows.take(50).map((row) {
                            final isTotals = row.isNotEmpty &&
                                (row[0]?.toString().toUpperCase() == 'TOTAL' ||
                                    row[0]?.toString().toUpperCase() == 'TOTALS');
                            return TableRow(
                              decoration: BoxDecoration(
                                color: isTotals ? const Color(0xFFF8FAFC) : Colors.white,
                              ),
                              children: List.generate(columns.length, (idx) {
                                final val = idx < row.length ? row[idx]?.toString() ?? '-' : '-';
                                final colHeader = columns[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Text(
                                    val,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: isTotals ? FontWeight.bold : FontWeight.w500,
                                      color: isTotals
                                          ? const Color(0xFF0F172A)
                                          : _colorForValue(colHeader, val),
                                    ),
                                    textAlign: _alignForColumn(colHeader),
                                  ),
                                );
                              }),
                            );
                          }),
                        ],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            "No report rows to preview in print format",
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 5. Formal Print Footer Signatures
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Note: This is a system-generated report.",
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              "Confidential • For internal company use only",
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildSignBlock("Prepared By"),
                            const SizedBox(width: 32),
                            _buildSignBlock("Authorized Signatory & Seal"),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildKpiItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  static Widget _buildVerticalSep() {
    return Container(
      width: 1,
      height: 22,
      color: const Color(0xFFCBD5E1),
    );
  }

  static Widget _buildSignBlock(String title) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 1,
          color: const Color(0xFF94A3B8),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  static TextAlign _alignForColumn(String col) {
    final c = col.toLowerCase();
    if (c.contains('hours') || c.contains('total') || c.contains('amount') || c.contains('days')) {
      return TextAlign.right;
    }
    if (c.contains('status') || c.contains('code') || c.contains('shift') || c == 'p' || c == 'a') {
      return TextAlign.center;
    }
    return TextAlign.left;
  }

  static Color _colorForValue(String header, String val) {
    final v = val.toUpperCase().trim();
    if (v == 'P' || v == 'PRESENT') return const Color(0xFF16A34A);
    if (v == 'A' || v == 'ABSENT') return const Color(0xFFDC2626);
    if (v == 'L' || v == 'LEAVE') return const Color(0xFFEAB308);
    if (v == 'HD' || v == 'HALF DAY') return const Color(0xFFEA580C);
    if (v == 'LT' || v == 'LATE') return const Color(0xFF7C3AED);
    return const Color(0xFF334155);
  }

  static Map<int, TableColumnWidth> _computeColumnWidths(List<String> cols) {
    final map = <int, TableColumnWidth>{};
    for (int i = 0; i < cols.length; i++) {
      final c = cols[i].toLowerCase();
      if (c.contains('name')) {
        map[i] = const FlexColumnWidth(2.5);
      } else if (c.contains('department') || c.contains('designation')) {
        map[i] = const FlexColumnWidth(2.0);
      } else if (c.contains('code') || c.contains('id') || c.contains('status')) {
        map[i] = const FlexColumnWidth(1.2);
      } else {
        map[i] = const FlexColumnWidth(1.4);
      }
    }
    return map;
  }
}
