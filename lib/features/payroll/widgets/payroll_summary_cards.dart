import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/payroll/core/payroll_model.dart';

/// PayrollSummaryCards - KPI Metrics Cards matching PayrollSummaryCards.jsx
/// Displays Total Run Gross, Net Employee Payout, Total Deductions, and Employees Processed.
class PayrollSummaryCards extends StatelessWidget {
  final PayrollRunSummary summary;

  const PayrollSummaryCards({
    super.key,
    required this.summary,
  });

  String _formatINR(double val) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(val);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final isMedium = constraints.maxWidth >= 500;

        if (isWide) {
          return Row(
            children: [
              Expanded(child: _buildGrossCard(context)),
              const SizedBox(width: 10),
              Expanded(child: _buildNetCard(context)),
              const SizedBox(width: 10),
              Expanded(child: _buildDeductionsCard(context)),
              const SizedBox(width: 10),
              Expanded(child: _buildEmployeesCard(context)),
            ],
          );
        } else if (isMedium) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildGrossCard(context)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildNetCard(context)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildDeductionsCard(context)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildEmployeesCard(context)),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildGrossCard(context)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildNetCard(context)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDeductionsCard(context)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildEmployeesCard(context)),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF383E47) : const Color(0xFFD0D7DE),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF57606A),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? (isDark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2937)),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6E7681),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildGrossCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      title: 'Total Run Gross',
      value: '₹${_formatINR(summary.totalGross)}',
      subtitle: 'Contractual gross',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA),
      iconBgColor: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF),
    );
  }

  Widget _buildNetCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      title: 'Net Employee Payout',
      value: '₹${_formatINR(summary.totalNet)}',
      subtitle: 'Net bank transfer',
      icon: Icons.check_circle_outline,
      iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
      iconBgColor: isDark ? const Color(0xFF065F46).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
      valueColor: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
    );
  }

  Widget _buildDeductionsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      title: 'Total Deductions',
      value: '₹${_formatINR(summary.totalDeductions)}',
      subtitle: 'LOP & statutory',
      icon: Icons.percent,
      iconColor: isDark ? const Color(0xFFFB7185) : const Color(0xFFF43F5E),
      iconBgColor: isDark ? const Color(0xFF881337).withValues(alpha: 0.4) : const Color(0xFFFFF1F2),
      valueColor: isDark ? const Color(0xFFFB7185) : const Color(0xFFF43F5E),
    );
  }

  Widget _buildEmployeesCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      title: 'Employees Processed',
      value: '${summary.employeeCount} Staff',
      subtitle: 'In selected run',
      icon: Icons.people_alt_outlined,
      iconColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
      iconBgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
    );
  }
}
