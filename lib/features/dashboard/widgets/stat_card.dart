import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String total;
  final String percentage;
  final String contextText;
  final bool isPositive;
  final IconData icon;
  final Color baseColor;
  final bool isCompact;

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
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on theme
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color;

    if (isCompact) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Title on left, small icon on right
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: baseColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    color: baseColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: baseColor, size: 10),
                ),
              ],
            ),

            // Value Row
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (total.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      total,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Trend / Context Row
            if (percentage.isNotEmpty || contextText.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (percentage.isNotEmpty) ...[
                      Text(
                        percentage,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    if (contextText.isNotEmpty)
                      Text(
                        contextText,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: subTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 2),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      borderRadius: 10,
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: baseColor.withValues(alpha: 0.5)),
                  color: baseColor.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: baseColor, size: 11),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (total.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        total,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Footer (Trends)
          if (percentage.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    percentage,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    contextText,
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: subTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// commit-marker: 2026-02-22T14:20:00+05:30
