import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_container.dart';

class AttendanceSuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final String type; // 'Check In' or 'Check Out'

  const AttendanceSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
  });

  static Future<void> show(BuildContext context, {required String type, required String time}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AttendanceSuccessDialog(
        title: "Success!",
        message: "Your attendance has been marked.",
        time: time,
        type: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTimeIn = type.toLowerCase().contains('in');
    final color = isTimeIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      alignment: Alignment.bottomCenter,
      child: GlassContainer(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon / Illustration
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ]
              ),
              child: Icon(
                isTimeIn ? Icons.login : Icons.logout,
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            
            // Text
            Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Marked Successfully",
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
                  shadowColor: color.withOpacity(0.5),
                ),
                child: Text(
                  "Done",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
