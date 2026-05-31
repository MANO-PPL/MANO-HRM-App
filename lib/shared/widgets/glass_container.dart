import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? color;
  final BoxBorder? border;
  final Gradient? gradient; // Added

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.blur = 40, 
    this.color,
    this.border,
    this.gradient, // Added
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!isDark) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          gradient: gradient, // Added
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ?? Border.all(color: Colors.grey[300]!, width: 1), 
          boxShadow: [
             BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), 
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      );
    }

    // Dark Mode: Solid Colors, No Glass Effect
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        // Use provided color OR default to Card Color (#1E2939). 
        color: color ?? const Color(0xFF161B22),
        gradient: gradient, // Added
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: const Color(0xFF30363D), width: 1), 
        boxShadow: const <BoxShadow>[], 
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}
