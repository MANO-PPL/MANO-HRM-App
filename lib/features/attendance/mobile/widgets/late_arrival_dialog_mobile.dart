import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/widgets/glass_container.dart';

class LateArrivalDialogMobile extends StatefulWidget {
  const LateArrivalDialogMobile({super.key});

  static Future<String?> show(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LateArrivalDialogMobile(),
    );
  }

  @override
  State<LateArrivalDialogMobile> createState() => _LateArrivalDialogMobileState();
}

class _LateArrivalDialogMobileState extends State<LateArrivalDialogMobile> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Colors.orange;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      alignment: Alignment.bottomCenter,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), // Unified padding
        borderRadius: 24,
        child: SingleChildScrollView( // Prevent overflow
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icon Header (Consistent with Tablet)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Icon(Icons.access_time_filled_rounded, color: color, size: 32),
                ),
                const SizedBox(height: 16),
                
                // 2. Title & Subtitle
                Text(
                  "Late Arrival",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "You are marking attendance after the scheduled time. Please strictly provide a valid reason.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12, // Smaller font for mobile
                    color: isDark ? Colors.white60 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Input Field
                Container(
                   decoration: BoxDecoration(
                     color: isDark ? const Color(0xFF30363D).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
                     borderRadius: BorderRadius.circular(16), // Consistent rounded corners
                     border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                   ),
                   child: TextFormField(
                    controller: _controller,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Reason is required' : null,
                    style: GoogleFonts.poppins(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Enter your reason here...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    minLines: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.grey,
                        ),
                        child: Text("Cancel", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(context, _controller.text.trim());
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shadowColor: color.withValues(alpha: 0.4),
                        ),
                        child: Text("Submit", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
