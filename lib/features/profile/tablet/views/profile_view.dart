import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/navigation/navigation_controller.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../main.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';

import '../../widgets/profile_avatar.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/custom_dialog.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Hero Profile Card
          _buildHeroCard(context, user),
          const SizedBox(height: 24),

          // Details Row
          LayoutBuilder(
            builder: (context, constraints) {
               // Threshold for Tablet Portrait (e.g., < 900 or even < 600 depending on content)
               // Using 900 to match previous logic for consistency
               final isPortrait = constraints.maxWidth < 900;

               if (isPortrait) {
                 return Column(
                   children: [
                     _buildContactInfoCard(context, user),
                     const SizedBox(height: 24),
                     _buildEmploymentDetailsCard(context, user),
                   ],
                 );
               }

               return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildContactInfoCard(context, user)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildEmploymentDetailsCard(context, user)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildLogoutCard(context),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, User? user) {
    final displayName = user?.name ?? 'User';
    final rawRole = user?.role ?? 'employee';
    final displayRole = rawRole.isNotEmpty 
        ? '${rawRole[0].toUpperCase()}${rawRole.substring(1)}'
        : 'Employee';

    return GlassContainer(
      padding: const EdgeInsets.all(40),
      child: Row(
        children: [
          // Avatar
          ProfileAvatar(
            size: 100,
            user: user,
            canEdit: true,
          ),
          const SizedBox(width: 32),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B60F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF5B60F6).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5B60F6)),
                      const SizedBox(width: 8),
                      Text(
                        displayRole,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5B60F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard(BuildContext context, User? user) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: user?.email ?? 'Not Available',
                  valueFontSize: 12,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Phone Number',
                  value: user?.phone ?? 'Not Set',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentDetailsCard(BuildContext context, User? user) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employment Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 32),
           Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.business_outlined,
                  label: 'Department',
                  value: user?.department ?? 'Not Set',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Employee ID',
                  value: user?.employeeId ?? 'Not Set',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, {required IconData icon, required String label, required String value, double? valueFontSize}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[400]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: valueFontSize ?? 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        CustomDialog.show(
          context: context,
          title: "Log Out",
          message: "Are you sure you want to log out?",
          positiveButtonText: "Log Out",
          isDestructive: true,
          onPositivePressed: () async {
            final authService = Provider.of<AuthService>(context, listen: false);
            await authService.logout();
            
            if (context.mounted) {
               // Reset internal navigation state
               navigationNotifier.value = PageType.dashboard;
               
               context.showToast('Logged out successfully', isSuccess: true);

              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
                (route) => false,
              );
            }
          },
          negativeButtonText: "Cancel",
          onNegativePressed: () {},
        );
      },
      child: GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        color: Colors.red.withOpacity(0.1), // Distinctive red tint
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
