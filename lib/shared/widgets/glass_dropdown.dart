
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final BoxBorder? border;

  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 8),
        ],
        GlassContainer(
          width: double.infinity,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          border: border,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: isDark ? const Color(0xFF30363D) : Colors.white,
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ],
    );
  }
}
