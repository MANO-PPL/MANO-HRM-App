import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';

class InteractiveImageViewerDialog extends StatefulWidget {
  final String imageUrl;
  final String title;

  const InteractiveImageViewerDialog({
    super.key,
    required this.imageUrl,
    this.title = "Image Preview",
  });

  static void show(BuildContext context, String imageUrl, {String title = "Image Preview"}) {
    if (imageUrl.trim().isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      builder: (context) => InteractiveImageViewerDialog(
        imageUrl: imageUrl.trim(),
        title: title,
      ),
    );
  }

  @override
  State<InteractiveImageViewerDialog> createState() => _InteractiveImageViewerDialogState();
}

class _InteractiveImageViewerDialogState extends State<InteractiveImageViewerDialog> {
  int _quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: isTablet ? 32 : 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 650 : double.infinity,
            maxHeight: size.height * 0.82,
          ),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 14 : 12,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Rotate 90°',
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 18),
                          ),
                          onPressed: () {
                            setState(() {
                              _quarterTurns = (_quarterTurns + 1) % 4;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                
                // Image Content
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.35),
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(30),
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6366F1)),
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, err, stack) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Could not load image from S3",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Pinch to zoom / Drag to pan",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_quarterTurns != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        "• Rotated ${_quarterTurns * 90}°",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF818CF8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
