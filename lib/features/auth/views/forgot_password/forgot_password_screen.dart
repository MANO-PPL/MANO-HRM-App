import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../verify_otp/verify_otp_screen.dart';
import 'mobile/forgot_password_mobile_portrait.dart';
import 'tablet/forgot_password_tablet_portrait.dart';
import 'tablet/forgot_password_tablet_landscape.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.forgotPassword(emailController.text.trim());

      if (!mounted) return;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent successfully. Please check your email.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(email: emailController.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lock orientation handling not needed here as LayoutBuilder handles it, 
    // but SystemUI mode can be set if needed.
    return Scaffold(
      // backgroundColor: const Color(0xFF0D1117), // Removed hardcoded color
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return ForgotPasswordMobilePortrait(controller: this);
          }
          return OrientationBuilder(
            builder: (_, orientation) {
              return orientation == Orientation.portrait
                  ? ForgotPasswordTabletPortrait(controller: this)
                  : ForgotPasswordTabletLandscape(controller: this);
            },
          );
        },
      ),
    );
  }
}
