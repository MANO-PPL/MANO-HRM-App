import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onPositivePressed;
  final String positiveButtonText;
  final VoidCallback? onNegativePressed;
  final String? negativeButtonText;
  final IconData? icon;
  final Color? iconColor;
  final bool isDestructive;
  final Color? positiveButtonColor;
  final AlignmentGeometry? alignment;
  final EdgeInsets? insetPadding;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onPositivePressed,
    this.positiveButtonText = 'Confirm',
    this.onNegativePressed,
    this.negativeButtonText,
    this.icon,
    this.iconColor,
    this.isDestructive = false,
    this.positiveButtonColor,
    this.alignment,
    this.insetPadding,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onPositivePressed,
    String positiveButtonText = 'Confirm',
    VoidCallback? onNegativePressed,
    String? negativeButtonText,
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
    Color? positiveButtonColor,
    AlignmentGeometry? alignment,
    EdgeInsets? insetPadding,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6), // Darker overlay for focus
      builder: (context) => CustomDialog(
        title: title,
        message: message,
        onPositivePressed: onPositivePressed,
        positiveButtonText: positiveButtonText,
        onNegativePressed: onNegativePressed,
        negativeButtonText: negativeButtonText,
        icon: icon,
        iconColor: iconColor,
        isDestructive: isDestructive,
        positiveButtonColor: positiveButtonColor,
        alignment: alignment,
        insetPadding: insetPadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: alignment,
      insetPadding: insetPadding ?? const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: _buildCardDialog(context),
    );
  }

  // Removed _buildGlassDialog as we want solid cards now

  Widget _buildCardDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildContent(context, isDark: isDark),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isDark}) {
    final textColor = isDark ? Colors.white : const Color(0xFF30363D);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (iconColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: iconColor ?? Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.5,
            color: subTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            if (negativeButtonText != null) ...[
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context, false); // Handle dismissal first
                    if (onNegativePressed != null) {
                      onNegativePressed!();
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    negativeButtonText!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Handle dismissal first
                  onPositivePressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive 
                      ? const Color(0xFFEF4444) 
                      : (positiveButtonColor ?? Theme.of(context).primaryColor),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  positiveButtonText,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
