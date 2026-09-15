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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 12,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: baseColor.withValues(alpha: 0.5)),
                  color: baseColor.withValues(alpha: 0.1),
                ),
                child: Icon(icon, color: baseColor, size: 12),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (total.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        total,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contextText,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: subTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// commit-marker: 2026-02-22T14:20:00+05:30

// [mod:2026-02-22T09:30:00+05:30]

// [upd:2026-05-10T14:00:00+05:30]

// [rev:2026-08-24T15:30:00+05:30]
