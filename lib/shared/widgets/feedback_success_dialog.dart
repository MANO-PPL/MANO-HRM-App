import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class FeedbackSuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'Feedback' or 'Bug Report'

  final double? width;
  final EdgeInsets? padding;

  const FeedbackSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.width,
    this.padding,
  });

  // Mobile: Standard width, standard padding
  static Future<void> showMobile(BuildContext context, {required String type}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FeedbackSuccessDialog(
        title: "Submitted!",
        message: "We've received your $type and sent a confirmation email.",
        type: type,
        width: 320, // Mobile specific width
      ),
    );
  }

  // Tablet Portrait: Wider, more padding
  static Future<void> showTabletPortrait(BuildContext context, {required String type}) async {
    await showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissal
      builder: (context) => FeedbackSuccessDialog(
        title: "Submitted!",
        message: "We've received your $type and sent a confirmation email.",
        type: type,
        width: 450, // Tablet Portrait specific width
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  // Tablet Landscape: Standard/Wide but constrained
  static Future<void> showTabletLandscape(BuildContext context, {required String type}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FeedbackSuccessDialog(
        title: "Submitted!",
        message: "We've received your $type and sent a confirmation email.",
        type: type,
        width: 450, // Tablet Landscape specific width
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  // Fallback / Generic
  static Future<void> show(BuildContext context, {required String type}) async {
    await showMobile(context, type: type);
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final isBug = type.toLowerCase().contains('bug');
    final color = isBug ? const Color(0xFFEF4444) : const Color(0xFF5B60F6);

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: width, // Apply specialized width
          constraints: const BoxConstraints(maxWidth: 500),
          child: GlassContainer(
            padding: padding ?? const EdgeInsets.all(32), // Apply specialized padding
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
          children: [
            // Icon / Illustration
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: Icon(
                Icons.check_rounded,
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            
            // Text
            Text(
              "Thank You!",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Submitted Successfully",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  shadowColor: color.withValues(alpha: 0.5),
                ),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            )
          ],
        ), // Column
      ), // GlassContainer
        ), // Container
      ), // Center
    ); // Dialog
  }
}
