import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixio/constants/app_colors.dart';
import 'package:fixio/routes/app_routes.dart';
import 'package:fixio/services/firebase_auth_service.dart';
import 'package:fixio/widgets/gradientbackground.dart';

class SignupDetailsScreen extends StatefulWidget {
  const SignupDetailsScreen({Key? key}) : super(key: key);

  @override
  State<SignupDetailsScreen> createState() => _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends State<SignupDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name     = TextEditingController();
  final TextEditingController _phone    = TextEditingController();
  final TextEditingController _city     = TextEditingController();
  final TextEditingController _password = TextEditingController();

  DateTime? _dob;
  File?     _profileImage;
  bool      _loading      = false;
  bool      _obscurePass  = true;
  String?   _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryBlue,
            surface: const Color(0xFF1E2340),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      setState(() => _error = "Please select your date of birth");
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    final result = await FirebaseAuthService().finalizeAccount(
      password:         _password.text.trim(),
      name:             _name.text.trim(),
      phone:            _phone.text.trim(),
      city:             _city.text.trim(),
      dob:              _dob!,
      profileImageFile: _profileImage, // ← actual File passed for Storage upload
    );

    if (!mounted) return;

    if (result == null) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (route) => false);
    } else {
      setState(() {
        _loading = false;
        _error   = result;
      });
    }
  }

  Widget _inputField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        bool isPass       = false,
        TextInputType? inputType,
        String? Function(String?)? extraValidator,
      }) {
    return TextFormField(
      controller:   controller,
      obscureText:  isPass ? _obscurePass : false,
      keyboardType: inputType ?? TextInputType.text,
      style:        const TextStyle(color: Colors.white),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "This field is required";
        if (isPass && v.length < 6) return "Password must be at least 6 characters";
        return extraValidator?.call(v);
      },
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPass
            ? IconButton(
          icon: Icon(
            _obscurePass ? Icons.visibility_off : Icons.visibility,
            color: Colors.white54,
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        )
            : null,
        filled:    true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   BorderSide(color: Colors.white.withOpacity(0.6), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Title
                const Text(
                  "Finalize Profile",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Almost there! Fill in your details.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // Profile image picker
                GestureDetector(
                  onTap: _loading ? null : _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 2.5,
                          ),
                        ),
                        child: _profileImage != null
                            ? ClipOval(
                          child: Image.file(
                            _profileImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white70,
                          size: 52,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _profileImage == null ? "Tap to add photo" : "Tap to change photo",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 28),

                // Form fields
                _inputField(_name, "Full Name", Icons.person_outline_rounded),
                const SizedBox(height: 14),
                _inputField(
                  _phone,
                  "Phone Number",
                  Icons.phone_outlined,
                  inputType: TextInputType.phone,
                  extraValidator: (v) {
                    if (v != null && v.length < 10) return "Enter a valid phone number";
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _inputField(_city, "City", Icons.location_city_outlined),
                const SizedBox(height: 14),
                _inputField(
                  _password,
                  "Create Password",
                  Icons.lock_outline_rounded,
                  isPass: true,
                ),
                const SizedBox(height: 14),

                // DOB Selector
                InkWell(
                  onTap: _loading ? null : _selectDOB,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined, color: Colors.white70),
                        const SizedBox(width: 12),
                        Text(
                          _dob == null
                              ? "Date of Birth"
                              : "${_dob!.day}/${_dob!.month}/${_dob!.year}",
                          style: TextStyle(
                            color: _dob == null
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _completeSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryBlue,
                      disabledBackgroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryBlue,
                      ),
                    )
                        : const Text(
                      "Save & Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Image Source Bottom Sheet ─────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2340),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Select Photo",
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SourceOption(
                icon: Icons.photo_library_rounded,
                label: "Gallery",
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              _SourceOption(
                icon: Icons.camera_alt_rounded,
                label: "Camera",
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}