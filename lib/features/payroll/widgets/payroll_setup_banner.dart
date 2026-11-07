import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PayrollSetupBanner - Onboarding alert banner matching PayrollSetupBanner.jsx
/// Displayed when initial payroll setup is required (no packages or unconfigured settings).
class PayrollSetupBanner extends StatelessWidget {
  final VoidCallback onConfigureSettings;

  const PayrollSetupBanner({
    super.key,
    required this.onConfigureSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;

        final button = ElevatedButton.icon(
          onPressed: onConfigureSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: const Icon(Icons.settings_outlined, size: 13),
          label: Text(
            'Configure Settings',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E38) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF3730A3).withValues(alpha: 0.5) : const Color(0xFFC7D2FE),
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.settings, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Initial Step Required: Configure Payroll Settings',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "Your company doesn't have any salary packages yet. Configuring payroll settings is the first thing you need to do.",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: button,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Initial Step Required: Configure Payroll Settings',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Your company doesn't have any salary packages yet. Configuring payroll settings is the first thing you need to do.",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    button,
                  ],
                ),
        );
      },
    );
  }
}
