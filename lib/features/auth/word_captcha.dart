import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/services/auth_service.dart';

class WordCaptcha extends StatefulWidget {
  final Function(String? id, String? value) onCaptchaChanged;

  const WordCaptcha({super.key, required this.onCaptchaChanged});

  @override
  State<WordCaptcha> createState() => _WordCaptchaState();
}

class _WordCaptchaState extends State<WordCaptcha> {
  String? _captchaId;
  String? _captchaSvgString;
  String? _errorMessage;
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  Future<void> _loadCaptcha() async {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Captcha Image Container
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF30363D) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
                child: _isLoading
                    ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _captchaSvgString != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SvgPicture.string(
                              _captchaSvgString!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 60,
                            ),
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _errorMessage ?? "Error loading captcha",
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 12),
            // Refresh Button
            InkWell(
              onTap: _loadCaptcha,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 60,
                width: 50,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF30363D) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
                child: Icon(
                  Icons.refresh,
                  color: isDark ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Input Field
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Enter characters above',
            hintStyle: GoogleFonts.poppins(fontSize: 14),
            prefixIcon: const Icon(Icons.security, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF30363D) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
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
