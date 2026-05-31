import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/constants/api_constants.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/toast_helper.dart';

class ProfileAvatar extends StatefulWidget {
  final double size;
  final User? user;
  final bool canEdit;

  const ProfileAvatar({
    super.key,
    required this.size,
    required this.user,
    this.canEdit = true,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  bool _isPickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (!widget.canEdit || _isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      // Validate Size (Max 5MB)
      final int sizeInBytes = await image.length();
      if (sizeInBytes > 5 * 1024 * 1024) {
         if (mounted) {
            context.showToast("The selected image is larger than 5MB. Please choose a smaller image.", isError: true);
         }
         return;
      }

      setState(() => _isUploading = true);

      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.updateProfilePicture(File(image.path));

      if (mounted) {
        // Evict from cache so new image loads
        if (widget.user?.profileImage != null) {
           final url = widget.user!.profileImage!.startsWith('http') 
               ? widget.user!.profileImage! 
               : '${ApiConstants.baseUrl}/${widget.user!.profileImage!}';
           
           await DefaultCacheManager().removeFile(url);
           await CachedNetworkImageProvider(url).evict();
        }

        if (mounted) {
          context.showToast("Profile picture updated successfully!", isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
         context.showToast("Could not update profile picture. Please try again.\nError: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isPickingImage = false;
        });
      }
    }
  }
  
  // This method will be called when the edit button is tapped
  void _showEditOptions() {
    if (!widget.canEdit) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Change Profile Photo",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionItem(
                  icon: Icons.camera_alt_outlined, 
                  label: "Camera", 
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  }
                ),
                _buildOptionItem(
                  icon: Icons.photo_library_outlined, 
                  label: "Gallery", 
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  }
                ),
                if (widget.user?.profileImage != null)
                  _buildOptionItem(
                    icon: Icons.delete_outline, 
                    label: "Remove", 
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      _confirmRemoveImage();
                    },
                    isDestructive: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveImage() async {
    CustomDialog.show(
      context: context,
      title: "Remove Photo",
      message: "Are you sure you want to remove your profile photo?",
      positiveButtonText: "Remove",
      isDestructive: true,
      onPositivePressed: () {
         _removeImage();
      },
      negativeButtonText: "Cancel",
      onNegativePressed: () {},
    );
  }

  Future<void> _removeImage() async {
      setState(() => _isUploading = true);
      
      // Capture URL before it's cleared from user object
      final String? urlToEvict = widget.user?.profileImage;

      try {
        if (!mounted) return;
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.deleteProfilePicture();

        if (mounted) {
          // Evict from cache
          if (urlToEvict != null) {
             final url = urlToEvict.startsWith('http') 
                 ? urlToEvict 
                 : '${ApiConstants.baseUrl}/$urlToEvict';
             
             await DefaultCacheManager().removeFile(url);
             await CachedNetworkImageProvider(url).evict();
          }

          if (mounted) {
            context.showToast("Profile photo removed successfully!", isSuccess: true);
          }
        }
      } catch (e) {
        if (mounted) {
           context.showToast("Could not remove profile photo. Please try again.\nError: $e", isError: true);
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
  }

  Widget _buildOptionItem({required IconData icon, required String label, required VoidCallback onTap, bool isDestructive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive ? const Color(0xFFEF4444) : (isDark ? Colors.white : Theme.of(context).primaryColor);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ensure min size
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDestructive 
                  ? const Color(0xFFEF4444).withValues(alpha: 0.1) 
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100]),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDestructive 
                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                    : (isDark ? Colors.white24 : (Colors.grey[300] ?? Colors.grey)),
              ),
            ),
            child: Icon(
              icon, 
              size: 28, 
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDestructive ? const Color(0xFFEF4444) : null,
              fontWeight: isDestructive ? FontWeight.w500 : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?';
    String? imageUrl = user?.profileImage;
    
    // URL Resolution
    if (imageUrl != null && !imageUrl.startsWith('http')) {
       imageUrl = '${ApiConstants.baseUrl}/$imageUrl';
    }

    debugPrint("Building ProfileAvatar: canEdit=${widget.canEdit}, size=${widget.size}");

    return Stack(
      clipBehavior: Clip.none, // Allow badge to overlap slightly if needed
      children: [
        GestureDetector(
          onTap: imageUrl != null ? () => _openViewer(imageUrl!) : null, // Pass resolved URL
          child: Hero(
            tag: 'profile-avatar-${user?.id ?? "me"}',
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: const Color(0xFF5B60F6).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF5B60F6).withValues(alpha: 0.3), width: 2),
              ),
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : imageUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (context, url, error) => _buildInitials(initials),
                          ),
                        )
                      : _buildInitials(initials),
            ),
          ),
        ),
        if (widget.canEdit && !_isUploading)
          Positioned(
            bottom: -5, // Slight negative to push it out a bit for better visibility
            right: -5,
            child: GestureDetector(
              onTap: _showEditOptions,
              child: Container(
                padding: const EdgeInsets.all(10), // Increased padding
                decoration: BoxDecoration(
                  color: const Color(0xFF5B60F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20), // Increased icon size
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(String imageUrl) { // Accept resolved URL
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const CircularProgressIndicator(),
                errorWidget: (context, url, err) => const Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
          Positioned(
             top: 40, right: 20,
             child: Material(
               color: Colors.transparent,
               child: IconButton(
                 icon: const Icon(Icons.close, color: Colors.white, size: 30),
                 onPressed: () => Navigator.pop(context),
               ),
             ),
          ),
        ],
      ),
    );
  }


  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: widget.size * 0.4,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF5B60F6),
        ),
      ),
    );
  }
}
