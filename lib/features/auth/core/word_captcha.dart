import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/services/auth_service.dart';

class WordCaptcha extends StatefulWidget {
  final Function(String? id, String? value) onCaptchaChanged;

  const WordCaptcha({super.key, required this.onCaptchaChanged});

  @override
  State<WordCaptcha> createState() => WordCaptchaState();
}

class WordCaptchaState extends State<WordCaptcha> {
  String? _captchaId;
  String? _captchaSvgString;
  String? _errorMessage;
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCaptcha();
  }

  Future<void> loadCaptcha() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _captchaSvgString = null; // Clear previous image while loading
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final data = await authService.fetchCaptcha();
      
      String? decodedSvg;
      try {
        String rawSvg = data['captchaSvg'].toString();
        if (rawSvg.contains('base64,')) {
           final split = rawSvg.split('base64,');
           if (split.length > 1) {
             // Clean the base64 string
             final base64String = split[1].replaceAll(RegExp(r'\s+'), '');
             decodedSvg = utf8.decode(base64.decode(base64String));
           } else {
             decodedSvg = rawSvg;
           }
        } else {
           decodedSvg = rawSvg;
        }
      } catch (e) {
        debugPrint("SVG Decoding Error: $e");
        decodedSvg = null;
      }

      if (mounted) {
        setState(() {
          _captchaId = data['captchaId'];
          _captchaSvgString = decodedSvg;
          _isLoading = false;
          _controller.clear();
          // Reset parent value
          widget.onCaptchaChanged(_captchaId, null);
        });
      }
    } catch (e) {
      debugPrint("Captcha Fetch Error: $e");
      if (mounted) {
        setState(() {
           _isLoading = false;
           _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security Verification',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Captcha Image Container
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      )
                    : _captchaSvgString != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: SvgPicture.string(
                              _captchaSvgString!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 52,
                            ),
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _errorMessage ?? "Error loading captcha",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.redAccent,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 12),
            // Refresh Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loadCaptcha,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Input Field
        TextFormField(
          controller: _controller,
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter captcha characters',
            hintStyle: GoogleFonts.inter(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            widget.onCaptchaChanged(_captchaId, value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter captcha';
            }
            return null;
          },
        ),
      ],
    );
  }
}

// [mod:2026-02-10T11:00:00+05:30]
