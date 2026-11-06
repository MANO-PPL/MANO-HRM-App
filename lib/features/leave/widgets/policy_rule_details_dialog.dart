import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PolicyRuleDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> rule;
  final String policyName;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PolicyRuleDetailsDialog({
    super.key,
    required this.rule,
    required this.policyName,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> rule,
    required String policyName,
    bool isAdmin = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PolicyRuleDetailsDialog(
        rule: rule,
        policyName: policyName,
        isAdmin: isAdmin,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = rule['name']?.toString() ?? 'Leave Rule';
    final code = rule['code']?.toString() ?? 'R';
    final maxBalance = rule['max_balance']?.toString() ?? '12';
    final rawAccrual = rule['accural_type']?.toString() ?? 'No Accrual';
    final isPaid = rule['is_paid'] == 1 || rule['is_paid'] == true;
    final requiresDoc = rule['requires_doc'] == 1 || rule['requires_doc'] == true;
    final carryForward = rule['carry_forward'] == 1 || rule['carry_forward'] == true;
    final carryMax = rule['carry_forward_max']?.toString() ?? '0';
    final encashable = rule['encashable'] == 1 || rule['encashable'] == true;

    // Friendly accrual info
    String accrualTitle = rawAccrual;
    String accrualDesc = 'All days allocated upfront at the beginning of the cycle.';
    IconData accrualIcon = Icons.calendar_today_outlined;
    Color accrualColor = const Color(0xFF6366F1);

    final lowerAccrual = rawAccrual.toLowerCase();
    if (lowerAccrual == 'comp_off' || lowerAccrual == 'comp off' || lowerAccrual == 'compoff') {
      accrualTitle = 'Compensatory Off (Comp Off)';
      accrualDesc = 'Earned by working extra hours, weekend shifts, or gazetted holidays.';
      accrualIcon = Icons.badge_outlined;
      accrualColor = const Color(0xFF8B5CF6);
    } else if (lowerAccrual == 'monthly') {
      final double mb = double.tryParse(maxBalance) ?? 12.0;
      accrualTitle = 'Monthly Accrual';
      accrualDesc = 'Credited monthly (${(mb / 12).toStringAsFixed(1)} days per month).';
      accrualIcon = Icons.date_range_outlined;
      accrualColor = const Color(0xFF10B981);
    } else if (lowerAccrual == 'quarterly') {
      final double mb = double.tryParse(maxBalance) ?? 12.0;
      accrualTitle = 'Quarterly Accrual';
      accrualDesc = 'Credited every 3 months (${(mb / 4).toStringAsFixed(1)} days per quarter).';
      accrualIcon = Icons.calendar_view_month_outlined;
      accrualColor = const Color(0xFF3B82F6);
    } else if (lowerAccrual == 'yearly') {
      accrualTitle = 'Yearly Accrual';
      accrualDesc = 'Allocated once per calendar year.';
      accrualIcon = Icons.event_repeat_outlined;
      accrualColor = const Color(0xFFF59E0B);
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.rule_folder_outlined, size: 22, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    code,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              policyName,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
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
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Status Badges Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5))
                        : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E8)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle_outline : Icons.cancel_outlined,
                        size: 13,
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid ? 'Paid Leave' : 'Unpaid Leave',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accrualColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(accrualIcon, size: 13, color: accrualColor),
                      const SizedBox(width: 4),
                      Text(
                        accrualTitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accrualColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detail Cards Grid
            _buildInfoCard(
              context,
              icon: Icons.event_available_outlined,
              iconColor: const Color(0xFF3B82F6),
              title: 'Days Per Year',
              value: '$maxBalance Days',
              description: 'Maximum quota allocated per calendar cycle.',
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            _buildInfoCard(
              context,
              icon: accrualIcon,
              iconColor: accrualColor,
              title: 'Accrual Schedule',
              value: accrualTitle,
              description: accrualDesc,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildCompactCard(
                    context,
                    title: 'Carry Forward',
                    value: carryForward ? 'Enabled (Max $carryMax d)' : 'Disabled (Expires)',
                    isPositive: carryForward,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCompactCard(
                    context,
                    title: 'Medical / Document',
                    value: requiresDoc ? 'Required' : 'Not Required',
                    isPositive: !requiresDoc,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildCompactCard(
              context,
              title: 'Payroll Encashment',
              value: encashable ? 'Encashable in Payroll' : 'Non-Encashable',
              isPositive: encashable,
              isDark: isDark,
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAdmin && onDelete != null) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    tooltip: 'Delete Rule',
                    onPressed: () {
                      Navigator.pop(context);
                      onDelete?.call();
                    },
                  ),
                  const Spacer(),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.inter(fontSize: 12)),
                ),
                if (isAdmin && onEdit != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text('Edit Rule', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit?.call();
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard(
    BuildContext context, {
    required String title,
    required String value,
    required bool isPositive,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
