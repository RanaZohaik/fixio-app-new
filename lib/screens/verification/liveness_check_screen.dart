// lib/screens/verification/liveness_check_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/verification_service.dart';

class LivenessCheckScreen extends StatefulWidget {
  const LivenessCheckScreen({super.key});

  @override
  State<LivenessCheckScreen> createState() => _LivenessCheckScreenState();
}

class _LivenessCheckScreenState extends State<LivenessCheckScreen>
    with SingleTickerProviderStateMixin {
  File? _selfie;
  bool _isUploading = false;
  bool _isProcessing = false; // Cloud Function is running
  String _processingMessage = "Uploading selfie...";
  late AnimationController _pulseController;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _captureSelfie() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (pickedFile == null) return;
    setState(() => _selfie = File(pickedFile.path));
  }

  Future<void> _uploadAndWaitForResult() async {
    if (_selfie == null) {
      await _captureSelfie();
      return;
    }

    setState(() {
      _isUploading = true;
      _processingMessage = "Uploading selfie...";
    });

    try {
      // ── Step 1: Upload selfie ──
      await VerificationService.uploadLivenessSelfie(
        _selfie!,
        onProgress: (p) {
          if (mounted) {
            setState(() =>
            _processingMessage = "Uploading... ${(p * 100).toInt()}%");
          }
        },
      );

      // ── Step 2: Wait for Cloud Function result ──
      setState(() {
        _isUploading = false;
        _isProcessing = true;
        _processingMessage = "Running liveness check...";
      });

      // Animate message changes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isProcessing) {
          setState(() => _processingMessage = "Matching face with CNIC...");
        }
      });
      Future.delayed(const Duration(seconds: 7), () {
        if (mounted && _isProcessing) {
          setState(() => _processingMessage = "Almost done...");
        }
      });

      final result = await VerificationService.waitForFaceMatchResult(
        timeout: const Duration(seconds: 90),
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // ── Step 3: Show result ──
      _showResultDialog(result);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showResultDialog(VerificationResult result) {
    final bool success = result.status == VerificationStatus.verified;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  color: success ? Colors.green : Colors.redAccent,
                ),
                child: Column(
                  children: [
                    Icon(
                      success ? Icons.verified_user : Icons.error_outline,
                      color: Colors.white,
                      size: 52,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      success ? "Verified!" : "Verification Failed",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      result.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    if (result.confidence != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        "Match confidence: ${result.confidence!.toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: success ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // close dialog
                          if (success) {
                            Navigator.pushReplacementNamed(context, "/home");
                          } else {
                            setState(() => _selfie = null); // reset to retake
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: success ? Colors.green : AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          success ? "Go to Dashboard" : "Try Again",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = _selfie != null;
    final bool busy = _isUploading || _isProcessing;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: busy
            ? const SizedBox()
            : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Liveness Check",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, Color(0xFF1A73E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
        ),
      ),
      body: busy ? _buildProcessingView() : _buildCaptureView(hasImage),
    );
  }

  // ── Processing View (shown while Cloud Function runs) ──
  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.08),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withOpacity(0.1 + _pulseController.value * 0.05),
                  ),
                  child: const Icon(Icons.face_retouching_natural,
                      size: 64, color: AppColors.primaryBlue),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _processingMessage,
                key: ValueKey(_processingMessage),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please keep the app open",
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Capture View (selfie camera UI) ──
  Widget _buildCaptureView(bool hasImage) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Center your face",
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  "Position your face within the frame in a well-lit environment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 40),

                // Selfie viewfinder
                GestureDetector(
                  onTap: _captureSelfie,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasImage
                              ? Colors.green.withOpacity(0.1)
                              : AppColors.primaryBlue.withOpacity(0.05),
                          border: Border.all(
                            color: hasImage
                                ? Colors.green
                                : AppColors.primaryBlue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          image: hasImage
                              ? DecorationImage(
                              image: FileImage(_selfie!), fit: BoxFit.cover)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5)
                          ],
                        ),
                        child: !hasImage
                            ? Icon(Icons.face_retouching_natural,
                            size: 80, color: Colors.grey[300])
                            : null,
                      ),
                      if (hasImage)
                        Positioned(
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(children: [
                              Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text("Retake",
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTipIcon(Icons.light_mode, "Good Light"),
                    _buildTipIcon(Icons.remove_red_eye, "Look Straight"),
                    _buildTipIcon(Icons.face, "No Glasses"),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _uploadAndWaitForResult,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                shadowColor: AppColors.primaryBlue.withOpacity(0.4),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasImage
                        ? [Colors.green, Colors.green.shade700]
                        : [AppColors.primaryBlue, const Color(0xFF1A73E8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          hasImage
                              ? Icons.check_circle_outline
                              : Icons.camera_alt_outlined,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        hasImage ? "Submit & Verify" : "Open Camera",
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}