import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BulkUploadReportDialog extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onHeaderClose;

  const BulkUploadReportDialog({
    super.key,
    required this.report,
    this.onHeaderClose,
  });

  @override
  Widget build(BuildContext context) {
    final int successCount = report['success_count'] ?? 0;
    final int failureCount = report['failure_count'] ?? 0;
    final int totalProcessed = report['total_processed'] ?? (successCount + failureCount);
    // 'errors' might be a List of strings or objects. Handling strings based on docs.
    final List<dynamic> errors = report['errors'] ?? [];

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF30363D) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Upload Processed!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            
            // Summary Text
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(text: 'Processed: '),
                  TextSpan(text: '$totalProcessed\n', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  const TextSpan(text: 'Success: '),
                  TextSpan(text: '$successCount\n', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const TextSpan(text: 'Failed/Skipped: '),
                  TextSpan(text: '$failureCount', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Errors & Warnings',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[400],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final error = errors[index].toString();
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 16, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: GoogleFonts.poppins(fontSize: 13, color: textColor),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            
            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // Close dialog
                  }
                  onHeaderClose?.call(); // Call parent refresh/close if provided
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
