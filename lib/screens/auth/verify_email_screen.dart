import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fixio/constants/app_colors.dart';
import 'package:fixio/routes/app_routes.dart';
import 'package:fixio/widgets/gradientbackground.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  // Password removed from constructor because it hasn't been created yet!
  const VerifyEmailScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _done = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Polls Firebase every 3 seconds to check if the user clicked the link
  void _startPolling() {
    _timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _checkVerification(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If user leaves the app to check email and comes back, check immediately
    if (state == AppLifecycleState.resumed) _checkVerification();
  }

  Future<void> _checkVerification() async {
    if (_done) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // Refresh user state from Firebase

      if (user != null && user.emailVerified) {
        _done = true;
        _timer?.cancel();

        // Success! Now go to the screen where they set their password and details
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.signupDetails,
          );
        }
      }
    } catch (e) {
      debugPrint("Verification check error: $e");
    }
  }

  Future<void> _resendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _resending = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification link resent to your inbox")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mark_email_unread,
                  size: size.width * 0.25,
                  color: Colors.white,
                ),
                const SizedBox(height: 30),
                Text(
                  "Verify Your Email",
                  style: TextStyle(
                    fontSize: size.width * 0.08,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "We've sent a verification link to:",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),

                // Resend Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resending ? null : _resendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlueDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _resending
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryBlueDark,
                      ),
                    )
                        : const Text(
                      "Resend Email",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const CircularProgressIndicator(color: Colors.white24),
                const SizedBox(height: 20),

                const Text(
                  "Waiting for you to click the link...",
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 40),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  child: const Text("Back to Login", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}