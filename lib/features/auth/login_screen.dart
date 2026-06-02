import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'word_captcha.dart'; // Import WordCaptcha
import 'mobile/views/login_mobile_portrait.dart';
import 'tablet/views/login_tablet_portrait.dart';
import 'tablet/views/login_tablet_landscape.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/toast_helper.dart';
import '../../shared/navigation/navigation_controller.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool rememberMe = false;

  void setRememberMe(bool value) {
    setState(() => rememberMe = value);
  }

  void toggleRememberMe() {
    setState(() => rememberMe = !rememberMe);
  }

  // New Captcha State
  String? captchaId;
  String? captchaValue;

  @override
  void initState() {
    super.initState();
    forceStartLocation();
  }

  Future<void> forceStartLocation() async {
    try {
      debugPrint("forceStartLocation initiated");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services are disabled.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        debugPrint("Location permission granted. Getting current position...");
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        debugPrint("Location successfully force-started: ${position.latitude}, ${position.longitude}");
      } else {
        debugPrint("Location permission denied: $permission");
      }
    } catch (e) {
      debugPrint("Error force starting location: $e");
    }
  }

  void togglePasswordVisibility() {
    setState(() => isPasswordVisible = !isPasswordVisible);
  }

  void onCaptchaChanged(String? id, String? value) {
    final bool wasValid = captchaValue != null && captchaValue!.isNotEmpty;
    final bool isValid = value != null && value.isNotEmpty;

    // Always update the values
    captchaId = id;
    captchaValue = value;

    // Only rebuild if the validity state changes (which affects the Login button)
    if (wasValid != isValid) {
      setState(() {});
    }
  }

  Future<void> handleLogin() async {
    if (!formKey.currentState!.validate()) return;

    if (captchaId == null || captchaValue == null || captchaValue!.isEmpty) {
      _showError('Please complete CAPTCHA verification');
      return;
    }

    setState(() => isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.login(
        identifierController.text.trim(),
        passwordController.text,
        captchaId!,
        captchaValue!,
        rememberMe: rememberMe,
      );

      if (!mounted) return;
      context.showToast("Logged in successfully!", isSuccess: true);
      // Reset navigation state to dashboard upon login
      navigateTo(PageType.dashboard);

      // Navigate to AuthWrapper to ensure clean state and proper redirection
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      _showError(e.toString());
      // Refresh captcha on error? Ideally yes, but WordCaptcha handles its own refresh.
      // We might want to force refresh it, but for now user can tap refresh.
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }



  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget buildCaptcha() {
    return WordCaptcha(onCaptchaChanged: onCaptchaChanged);
  }



  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return LoginMobilePortrait(controller: this);
          }
          return OrientationBuilder(
            builder: (_, orientation) {
              return orientation == Orientation.portrait
                  ? LoginTabletPortrait(controller: this)
                  : LoginTabletLandscape(controller: this);
            },
          );
        },
      ),
    );
  }
}
