
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final int maxLines;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final BoxBorder? border; // Added

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.keyboardType,
    this.validator,
    this.border, // Added
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassContainer(
      width: double.infinity,
      borderRadius: 12,
      border: border, // Added
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white54 : Colors.black45),
          prefixIcon: prefixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
