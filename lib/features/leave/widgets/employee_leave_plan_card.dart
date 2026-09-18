import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmployeeLeavePlanCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final Map<String, dynamic>? balance;
  final int index;

  const EmployeeLeavePlanCard({
    super.key,
    required this.rule,
    this.balance,
    required this.index,
  });

  static const List<Color> _paletteColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFF43F5E), // Rose
    Color(0xFF14B8A6), // Teal
    Color(0xFFF59E0B), // Amber
    Color(0xFFA855F7), // Purple
    Color(0xFF0EA5E9), // Sky
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _paletteColors[index % _paletteColors.length];

    final ruleMax = num.tryParse(rule['max_balance']?.toString() ?? '0') ?? 0;
    final allocated = (balance != null && (num.tryParse(balance?['allocated']?.toString() ?? '0') ?? 0) > 0)
        ? (num.tryParse(balance?['allocated']?.toString() ?? '0') ?? 0)
        : ruleMax;
    final carried = num.tryParse(balance?['carried_forward']?.toString() ?? '0') ?? 0;
    final total = allocated + carried;
    final used = num.tryParse(balance?['used']?.toString() ?? '0') ?? 0;
    final available = (balance != null && balance?['available'] != null)
        ? (num.tryParse(balance?['available']?.toString() ?? '0') ?? 0)
        : (total - used > 0 ? total - used : 0);
    final displayDays = available;
    final remainingPct = total > 0 ? ((displayDays / total) * 100).round().clamp(0, 100) : 0;
    final progress = remainingPct / 100.0;

    final ruleName = rule['name']?.toString() ?? balance?['leave_type']?.toString() ?? 'Leave';
    final ruleCode = rule['code']?.toString() ?? balance?['leave_code']?.toString() ?? 'L';
    final rawAccrual = rule['accural_type']?.toString();
    final accrualSubtitle = (rawAccrual != null && rawAccrual.isNotEmpty && rawAccrual != 'No Accrual')
        ? '$rawAccrual accrual'
        : 'All days available upfront';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Panel with Circular Ring
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                border: Border(
                  right: BorderSide(
                    color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(64, 64),
                    painter: _CircularProgressPainter(
                      progress: progress,
                      color: primaryColor,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                    ),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayDays % 1 == 0 ? displayDays.toInt().toString() : displayDays.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'days',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ruleCode,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ruleName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          accrualSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: isDark ? const Color(0xFF8D96A0) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Balance Bar Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: displayDays % 1 == 0 ? '${displayDays.toInt()} ' : '${displayDays.toStringAsFixed(1)} ',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'days left',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      color: isDark ? const Color(0xFF8D96A0) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$used used / $total total',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF8D96A0) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 7,
                            width: double.infinity,
                            color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$remainingPct% remaining',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              '$total days total allowance',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF8D96A0) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Feature tags
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildTag(
                          label: (rule['is_paid'] == true || rule['is_paid'] == 1) ? 'Paid Leave' : 'Unpaid Leave',
                          textColor: (rule['is_paid'] == true || rule['is_paid'] == 1) ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.black54),
                          bgColor: (rule['is_paid'] == true || rule['is_paid'] == 1) ? const Color(0xFF10B981).withValues(alpha: 0.12) : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
                          borderColor: (rule['is_paid'] == true || rule['is_paid'] == 1) ? const Color(0xFF10B981).withValues(alpha: 0.3) : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                        ),
                        if (rule['requires_doc'] == 1 || rule['requires_doc'] == true)
                          _buildTag(
                            label: 'Doc Required',
                            textColor: const Color(0xFFF59E0B),
                            bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        if (rule['carry_forward'] == 1 || rule['carry_forward'] == true)
                          _buildTag(
                            label: 'Carry Fwd',
                            textColor: const Color(0xFF0EA5E9),
                            bgColor: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                            borderColor: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          ),
                        if (rule['encashable'] == 1 || rule['encashable'] == true)
                          _buildTag(
                            label: 'Encashable',
                            textColor: const Color(0xFFA855F7),
                            bgColor: const Color(0xFFA855F7).withValues(alpha: 0.12),
                            borderColor: const Color(0xFFA855F7).withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 5) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Active sweep
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
