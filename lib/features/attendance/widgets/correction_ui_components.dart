
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CorrectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose; // Added onClose

  const CorrectionHeader({super.key, required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.info_outline, color: Color(0xFF4F46E5), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded( // Added Expanded to push current title to fill space
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: Theme.of(context).disabledColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class CorrectionLabel extends StatelessWidget {
  final String label;
  const CorrectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class CorrectionInputField extends StatelessWidget {
  final String value;
  final String? hintText;
  final VoidCallback onTap;
  final IconData? suffixIcon;
  final bool isMultiline;
  final bool isLoading;

  const CorrectionInputField({
    super.key,
    required this.value,
    this.hintText,
    required this.onTap,
    this.suffixIcon,
    this.isMultiline = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isMultiline ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? (hintText ?? '') : value,
                style: GoogleFonts.poppins(
                  color: value.isEmpty 
                      ? (isDark ? Colors.white38 : const Color(0xFF9CA3AF)) 
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                  fontSize: 14,
                ),
                maxLines: isMultiline ? 4 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              )
            else if (suffixIcon != null)
              Icon(suffixIcon, size: 18, color: isDark ? Colors.white70 : const Color(0xFF1F2937)),
          ],
        ),
      ),
    );
  }
}

class CorrectionTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool isDark;

  const CorrectionTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : const Color(0xFF1F2937),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

class CorrectionSegmentedControl<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const CorrectionSegmentedControl({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: items.entries.map((entry) {
          final isSelected = value == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.2) : Colors.white) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected && !isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                  border: isSelected && isDark 
                      ? Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.5)) 
                      : null,
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)) 
                          : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CorrectionDashedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CorrectionDashedButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // Border property is used by custom painter
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashWidth = 5;
    const double dashSpace = 3;

    final RRect rrect = RRect.fromLTRBR(
      0, 0, size.width, size.height,
      const Radius.circular(12),
    );

    final Path path = Path()..addRRect(rrect);
    
    final Path dashedPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => true;
}

class CorrectionSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  const CorrectionSubmitButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.check, size: 20),
                   const SizedBox(width: 8),
                   Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CorrectionDetailCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? backgroundColor;
  final Color? textColor;

  const CorrectionDetailCard({
    super.key,
    required this.label,
    required this.value,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor ?? (isDark ? Colors.white : const Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }
}

class CorrectionAuditItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLast;

  const CorrectionAuditItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4F46E5), width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// [upd:2026-04-16T14:00:00+05:30]
