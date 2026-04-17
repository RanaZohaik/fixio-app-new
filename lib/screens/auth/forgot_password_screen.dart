import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixio/constants/app_colors.dart';
import 'package:fixio/widgets/gradientbackground.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _loading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: GradientBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Back Button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            /// APP NAME / LOGO
            Text(
              "Fixio",
              style: TextStyle(
                fontSize: size.width * 0.12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 10),

            /// Main Icon
            Icon(
              Icons.lock_reset_rounded,
              size: size.width * 0.20,
              color: Colors.white.withOpacity(0.9),
            ),

            const SizedBox(height: 20),

            /// Title
            Text(
              "Reset Password",
              style: TextStyle(
                fontSize: size.width * 0.065,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 10),

            /// Subtitle
            Text(
              "Enter your registered email and we’ll send you a reset link.",
              style: TextStyle(
                fontSize: size.width * 0.04,
                color: Colors.white.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            /// FORM
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Email address",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) {
                      v = v?.trim();
                      if (v == null || v.isEmpty) return "Email is required";
                      if (!v.contains("@") || !v.contains(".")) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlueDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text("Send Reset Link", style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// Message
                  if (_message != null)
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message!.startsWith("✔")
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _email.text.trim();

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _message = "✔ Reset link sent. Check your inbox.");
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = e.code == "user-not-found"
            ? "No account exists with this email."
            : (e.message ?? "Something went wrong.");
      });
    } finally {
      setState(() => _loading = false);
    }
  }
}
