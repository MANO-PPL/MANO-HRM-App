import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/widgets/toast_helper.dart';
import '../../../shared/widgets/loading_screen.dart';
import '../../../main.dart';
import '../mobile/views/force_password_change_mobile_portrait.dart';
import '../tablet/views/force_password_change_tablet_portrait.dart';
import '../tablet/views/force_password_change_tablet_landscape.dart';

class ForcePasswordChangeScreen extends StatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  State<ForcePasswordChangeScreen> createState() => ForcePasswordChangeScreenState();
}

class ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void togglePasswordVisibility() {
    setState(() => isPasswordVisible = !isPasswordVisible);
  }

  void toggleConfirmPasswordVisibility() {
    setState(() => isConfirmPasswordVisible = !isConfirmPasswordVisible);
  }

  Future<void> handlePasswordChange() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.changePassword(passwordController.text);

      if (!mounted) return;
      context.showToast("Password updated successfully!", isSuccess: true);

      // Navigate to AuthWrapper to load Dashboard cleanly
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> handleLogout() async {
    setState(() => isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return ForcePasswordChangeMobilePortrait(controller: this);
                }
                return OrientationBuilder(
                  builder: (_, orientation) {
                    return orientation == Orientation.portrait
                        ? ForcePasswordChangeTabletPortrait(controller: this)
                        : ForcePasswordChangeTabletLandscape(controller: this);
                  },
                );
              },
            ),
            if (isLoading)
              Positioned.fill(
                child: const LoadingScreen(
                  message: "Processing updates...",
                ),
              ),
          ],
        ),
      ),
    );
  }
}
