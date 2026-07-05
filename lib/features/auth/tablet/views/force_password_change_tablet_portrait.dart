import 'package:flutter/material.dart';
import '../../views/force_password_change_screen.dart';

class ForcePasswordChangeTabletPortrait extends StatelessWidget {
  final ForcePasswordChangeScreenState controller;

  const ForcePasswordChangeTabletPortrait({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Reset Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Change Password Required',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'For security purposes, you are required to change your password before using the platform.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 48),

              Card(
                elevation: 4,
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Form(
                    key: controller.formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // New Password Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: controller.passwordController,
                              obscureText: !controller.isPasswordVisible,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter new password',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  size: 24,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    size: 24,
                                    color: isDark ? Colors.white30 : Colors.black38,
                                  ),
                                  onPressed: controller.togglePasswordVisibility,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Confirm Password Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm New Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: controller.confirmPasswordController,
                              obscureText: !controller.isConfirmPasswordVisible,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 16,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != controller.passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Confirm new password',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_clock_outlined,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                  size: 24,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    controller.isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    size: 24,
                                    color: isDark ? Colors.white30 : Colors.black38,
                                  ),
                                  onPressed: controller.toggleConfirmPasswordVisibility,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),

                        // Action Buttons
                        ElevatedButton(
                          onPressed: controller.handlePasswordChange,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update Password',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: controller.handleLogout,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancel & Log Out',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
