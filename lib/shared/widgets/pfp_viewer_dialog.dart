import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/constants/api_constants.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';

/// WhatsApp-style profile picture preview and full-screen viewer dialog.
/// Supports viewing any user's profile picture with WhatsApp-like card popup,
/// full-screen pinch-to-zoom, and optional profile photo editing.
class PfpViewerDialog extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? subtitle;
  final String? heroTag;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onViewProfile;

  const PfpViewerDialog({
    super.key,
    required this.imageUrl,
    required this.name,
    this.subtitle,
    this.heroTag,
    this.canEdit = false,
    this.onEdit,
    this.onViewProfile,
  });

  /// Displays the WhatsApp-style popup card preview
  static Future<void> show(
    BuildContext context, {
    required String? imageUrl,
    required String name,
    String? subtitle,
    String? heroTag,
    String? tag,
    bool canEdit = false,
    VoidCallback? onEdit,
    VoidCallback? onViewProfile,
  }) {
    // Resolve relative image URLs to backend base URL
    String? resolvedUrl = imageUrl;
    if (resolvedUrl != null &&
        resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('http')) {
      resolvedUrl = '${ApiConstants.baseUrl}/$resolvedUrl';
    }

    final effectiveHeroTag = heroTag ?? tag;

    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: PfpViewerDialog(
          imageUrl: resolvedUrl,
          name: name,
          subtitle: subtitle,
          heroTag: effectiveHeroTag,
          canEdit: canEdit,
          onEdit: onEdit,
          onViewProfile: onViewProfile,
        ),
      ),
    );
  }

  /// Displays the full-screen pinch-to-zoom image viewer
  static void openFullscreen(
    BuildContext context, {
    required String imageUrl,
    required String name,
    String? heroTag,
    bool canEdit = false,
    VoidCallback? onEdit,
    VoidCallback? onViewProfile,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (ctx, anim1, anim2) => _FullscreenPfpViewer(
          imageUrl: imageUrl,
          name: name,
          heroTag: heroTag,
          canEdit: canEdit,
          onEdit: onEdit,
          onViewProfile: onViewProfile,
        ),
        transitionsBuilder: (ctx, anim1, anim2, child) =>
            FadeTransition(opacity: anim1, child: child),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    if (onViewProfile != null) {
      onViewProfile!();
    } else {
      navigateTo(PageType.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.84).clamp(280.0, 380.0);
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join('').toUpperCase()
        : '?';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── WhatsApp-style Image Container with Gradient Overlay ─────
              GestureDetector(
                onTap: hasImage
                    ? () {
                        Navigator.of(context).pop();
                        openFullscreen(
                          context,
                          imageUrl: imageUrl!,
                          name: name,
                          heroTag: heroTag,
                          canEdit: canEdit,
                          onEdit: onEdit,
                        );
                      }
                    : null,
                child: SizedBox(
                  width: cardWidth,
                  height: cardWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Profile Picture or Styled Initial Placeholder
                      if (hasImage)
                        Hero(
                          tag: heroTag ?? 'pfp-dialog-${imageUrl!}',
                          child: CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, err) => _buildFallbackAvatar(initials, isDark),
                          ),
                        )
                      else
                        _buildFallbackAvatar(initials, isDark),

                      // Top Gradient Overlay (WhatsApp-style dark scrim with name)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 10, 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.75),
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _openProfile(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      name,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                        shadows: const [
                                                          Shadow(color: Colors.black54, blurRadius: 4),
                                                        ],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 18,
                                                    color: Colors.white70,
                                                  ),
                                                ],
                                              ),
                                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                                const SizedBox(height: 1),
                                                Text(
                                                  subtitle!,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white.withValues(alpha: 0.85),
                                                    shadows: const [
                                                      Shadow(color: Colors.black54, blurRadius: 4),
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Close Button (X)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                                onPressed: () => Navigator.of(context).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        ),
                      ),


                    ],
                  ),
                ),
              ),

              // ── WhatsApp Bottom Action Bar ────────────────────────────────
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // View Profile Button (WhatsApp's Info action)
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.person_outline_rounded,
                        label: "Profile",
                        onTap: () => _openProfile(context),
                        isDark: isDark,
                      ),
                    ),

                    // Full Screen Button
                    if (hasImage)
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.open_in_full_rounded,
                          label: "Full View",
                          onTap: () {
                            Navigator.of(context).pop();
                            openFullscreen(
                              context,
                              imageUrl: imageUrl!,
                              name: name,
                              heroTag: heroTag,
                              canEdit: canEdit,
                              onEdit: onEdit,
                              onViewProfile: onViewProfile,
                            );
                          },
                          isDark: isDark,
                        ),
                      ),

                    // Change Photo Button (if can edit)
                    if (canEdit)
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.camera_alt_outlined,
                          label: hasImage ? "Change" : "Upload",
                          onTap: () {
                            Navigator.of(context).pop();
                            if (onEdit != null) {
                              onEdit!();
                            } else {
                              _showDefaultEditSheet(context);
                            }
                          },
                          isDark: isDark,
                        ),
                      ),

                    // Close Button
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.close_rounded,
                        label: "Close",
                        onTap: () => Navigator.of(context).pop(),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String initials, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "No profile photo set",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showDefaultEditSheet(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Change Profile Photo",
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionItem(
                    ctx,
                    icon: Icons.camera_alt_outlined,
                    label: "Camera",
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                      if (file != null) {
                        try {
                          await auth.updateProfilePicture(File(file.path));
                          if (context.mounted) context.showToast("Profile photo updated!", isSuccess: true);
                        } catch (e) {
                          if (context.mounted) context.showToast("Upload failed: $e", isError: true);
                        }
                      }
                    },
                  ),
                  _buildOptionItem(
                    ctx,
                    icon: Icons.photo_library_outlined,
                    label: "Gallery",
                    onTap: () async {
                      Navigator.pop(ctx);
                      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (file != null) {
                        try {
                          await auth.updateProfilePicture(File(file.path));
                          if (context.mounted) context.showToast("Profile photo updated!", isSuccess: true);
                        } catch (e) {
                          if (context.mounted) context.showToast("Upload failed: $e", isError: true);
                        }
                      }
                    },
                  ),
                  if (auth.user?.profileImage != null)
                    _buildOptionItem(
                      ctx,
                      icon: Icons.delete_outline_rounded,
                      label: "Remove",
                      isDestructive: true,
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await auth.deleteProfilePicture();
                          if (context.mounted) context.showToast("Profile photo removed", isSuccess: true);
                        } catch (e) {
                          if (context.mounted) context.showToast("Could not remove photo: $e", isError: true);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF6366F1);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen zoomable lightbox for profile picture
class _FullscreenPfpViewer extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String? heroTag;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onViewProfile;

  const _FullscreenPfpViewer({
    required this.imageUrl,
    required this.name,
    this.heroTag,
    this.canEdit = false,
    this.onEdit,
    this.onViewProfile,
  });

  @override
  State<_FullscreenPfpViewer> createState() => _FullscreenPfpViewerState();
}

class _FullscreenPfpViewerState extends State<_FullscreenPfpViewer> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pinch-to-zoom interactive viewer
          Center(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.8,
              maxScale: 4.5,
              child: Hero(
                tag: widget.heroTag ?? 'pfp-fullscreen-${widget.imageUrl}',
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                      strokeWidth: 2,
                    ),
                  ),
                  errorWidget: (context, url, err) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          "Failed to load image",
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top App Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 6,
                12,
                16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
                    tooltip: "View Profile",
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (widget.onViewProfile != null) {
                        widget.onViewProfile!();
                      } else {
                        navigateTo(PageType.profile);
                      }
                    },
                  ),
                  if (widget.canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                      tooltip: "Change Photo",
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (widget.onEdit != null) {
                          widget.onEdit!();
                        } else {
                          PfpViewerDialog._showDefaultEditSheet(context);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
