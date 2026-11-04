import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';

class AvatarPreviewDialog extends StatelessWidget {
  final String displayName;
  final String initials;
  final String? avatarUrl;
  final bool isGroup;

  const AvatarPreviewDialog({
    super.key,
    required this.displayName,
    required this.initials,
    this.avatarUrl,
    this.isGroup = false,
  });

  static String? resolveAvatarUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return '${ApiConstants.baseUrl}/${trimmed.startsWith('/') ? trimmed.substring(1) : trimmed}';
  }

  static LinearGradient getAvatarGradient(String name) {
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final index = hash % 5;
    const gradients = [
      LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[index];
  }

  static void show(
    BuildContext context, {
    required String displayName,
    required String initials,
    String? avatarUrl,
    bool isGroup = false,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Avatar Preview',
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return AvatarPreviewDialog(
          displayName: displayName,
          initials: initials,
          avatarUrl: avatarUrl,
          isGroup: isGroup,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          ),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardSize = min(screenSize.width * 0.78, 300.0);
    final resolvedUrl = resolveAvatarUrl(avatarUrl);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardSize,
          height: cardSize,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Avatar content (Zoomable & Interactive)
                InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 3.5,
                  child: resolvedUrl != null && resolvedUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: resolvedUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF0D1117),
                            child: const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF5B60F6),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildFallback(cardSize),
                        )
                      : _buildFallback(cardSize),
                ),

                // Top subtle header overlay with name and close button
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(double size) {
    if (isGroup) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.groups,
            size: size * 0.45,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: getAvatarGradient(displayName),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

