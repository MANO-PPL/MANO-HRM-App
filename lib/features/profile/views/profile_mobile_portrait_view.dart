import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/navigation/navigation_controller.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/main.dart';
import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/services/chatbot_service.dart';

import 'package:flutter_application/features/profile/widgets/profile_avatar.dart';
import 'package:flutter_application/shared/models/user_model.dart';
import 'package:flutter_application/shared/utils/error_logger.dart';

class MobileProfileContent extends StatefulWidget {
  const MobileProfileContent({super.key});

  @override
  State<MobileProfileContent> createState() => _MobileProfileContentState();
}

class _MobileProfileContentState extends State<MobileProfileContent> {
  int _logCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).fetchUserProfile();
    });
    _loadLogCount();
  }

  Future<void> _loadLogCount() async {
    final logs = await ErrorLogger.getErrors();
    if (mounted) {
      setState(() {
        _logCount = logs.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          // Hero Profile Card
          _buildHeroCard(context, user),
          const SizedBox(height: 10),

          // Contact Info Card
          _buildContactInfoCard(context, user),
          const SizedBox(height: 10),

          // Employment Details Card
          _buildEmploymentDetailsCard(context, user),
          const SizedBox(height: 10),

          // Settings Card
          _buildSettingsCard(context),
          const SizedBox(height: 10),

          // Diagnostics Card
          _buildDiagnosticsCard(context),
          const SizedBox(height: 10),

          // Logout Card
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column( // Stacked for Mobile
        children: [
          // Avatar
          ProfileAvatar(
            size: 62,
            user: user,
            canEdit: true,
          ),
          const SizedBox(height: 10),

          // Info
          Text(
            displayName,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5B60F6).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF5B60F6)),
                const SizedBox(width: 6),
                Text(
                  displayRole,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5B60F6),
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 10),
          // Vertical Stack for Mobile
          _buildInfoItem(
            context,
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: user?.email ?? 'Not Available',
            valueFontSize: 12,
          ),
          const SizedBox(height: 10),
          _buildInfoItem(
            context,
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: user?.phone ?? 'Not Set',
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentDetailsCard(BuildContext context, User? user) {
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Employment Details',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 10),
          // Vertical Stack
          _buildInfoItem(
            context,
            icon: Icons.business_outlined,
            label: 'Department',
            value: user?.department ?? 'Not Set',
          ),
          const SizedBox(height: 10),
          _buildInfoItem(
            context,
            icon: Icons.badge_outlined,
            label: 'Employee ID',
            value: user?.employeeId ?? 'Not Set',
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        color: const Color(0xFFEF4444), // Solid Red
        border: Border.all(color: Colors.red.shade700),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final chatbotService = Provider.of<ChatbotService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Settings',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.smart_toy_outlined, size: 18, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mano Copilot (AI Chatbot)',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Show chatbot assistant button',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: chatbotService.isChatbotEnabled,
                activeTrackColor: const Color(0xFF5B60F6),
                onChanged: (val) {
                  chatbotService.setChatbotEnabled(val);
                  context.showToast(
                    val ? 'Chatbot enabled' : 'Chatbot disabled',
                    isSuccess: true,
                  );
                },
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[400]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: valueFontSize ?? 12.5,
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

  Widget _buildDiagnosticsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnostics & Logs',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Colors.white10),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.terminal_outlined, size: 18, color: Colors.grey[400]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Unsent Logs',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _logCount == 0
                          ? '0 unsent error logs stored locally.'
                          : '$_logCount unsent error logs stored locally.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _logCount == 0
                      ? null
                      : () async {
                          await ErrorLogger.exportErrors(context);
                        },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B60F6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    disabledForegroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_logCount > 0) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    CustomDialog.show(
                      context: context,
                      title: "Clear Logs",
                      message: "Are you sure you want to clear all local diagnostic logs?",
                      positiveButtonText: "Clear",
                      isDestructive: true,
                      onPositivePressed: () async {
                        await ErrorLogger.clearErrors();
                        await _loadLogCount();
                        if (context.mounted) {
                          context.showToast('Diagnostic logs cleared', isSuccess: true);
                        }
                      },
                      negativeButtonText: "Cancel",
                      onNegativePressed: () {},
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.red,
                    shadowColor: Colors.transparent,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// [mod:2026-02-27T09:00:00+05:30]

// [upd:2026-05-01T11:30:00+05:30]
