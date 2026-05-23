import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/widgets/glass_container.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String total;
  final String percentage;
  final String contextText;
  final bool isPositive;
  final IconData icon;
  final Color baseColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.total,
    required this.percentage,
    required this.contextText,
    required this.isPositive,
    required this.icon,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on theme
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

    return GlassContainer(
      padding: const EdgeInsets.all(16), // Reduced padding from 20 to 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12, // Reduced from 13
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28, // Reduced from 32
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: baseColor.withValues(alpha: 0.5)),
                  color: baseColor.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: baseColor, size: 14), // Reduced from 16
              ),
            ],
          ),
          
          // Value
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      total,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer (Trends)
          if (percentage.isNotEmpty)
            Row(
              children: [
                Text(
                  percentage,
                  style: GoogleFonts.poppins(
                    fontSize: 11, // Reduced from 12
                    fontWeight: FontWeight.w600,
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    contextText,
                    style: GoogleFonts.poppins(
                      fontSize: 11, // Reduced from 12
                      color: subTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
