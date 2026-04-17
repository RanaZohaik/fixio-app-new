import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/verification_service.dart';

class CnicUploadScreen extends StatefulWidget {
  const CnicUploadScreen({super.key});

  @override
  State<CnicUploadScreen> createState() => _CnicUploadScreenState();
}

class _CnicUploadScreenState extends State<CnicUploadScreen> {
  File? _frontImage;
  File? _backImage;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String side) async {
    // Enhanced: Allow picking from gallery (could be expanded to camera easily)
    final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85
    );

    if (pickedFile == null) return;

    setState(() {
      if (side == "front") _frontImage = File(pickedFile.path);
      if (side == "back") _backImage = File(pickedFile.path);
    });
  }

  Future<void> _uploadImages() async {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload both front and back images"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await VerificationService.uploadCnicImage(_frontImage!, side: "front");
      await VerificationService.uploadCnicImage(_backImage!, side: "back");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Documents submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamed(context, "/liveness-check");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Upload Identity",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
      body: Column(
        children: [
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 1. Guidance Section
                  _buildGuidanceSection(),
                  const SizedBox(height: 25),

                  // 2. Front Image Slot
                  _buildSectionHeader("Front Side", "Your photo and name should be clear"),
                  const SizedBox(height: 10),
                  _buildUploadSlot(
                    side: "front",
                    file: _frontImage,
                    icon: Icons.account_box_outlined,
                  ),

                  const SizedBox(height: 25),

                  // 3. Back Image Slot
                  _buildSectionHeader("Back Side", "Barcode and address must be visible"),
                  const SizedBox(height: 10),
                  _buildUploadSlot(
                    side: "back",
                    file: _backImage,
                    icon: Icons.flip_to_back_outlined,
                  ),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),

          // Pinned Bottom Button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  "Submit Documents",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildGuidanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tips for quick approval:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 5),
                _buildBulletPoint("Make sure the card is physically present."),
                _buildBulletPoint("Avoid flash glare on the card."),
                _buildBulletPoint("Ensure all 4 corners are visible."),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildUploadSlot({
    required String side,
    required File? file,
    required IconData icon,
  }) {
    final bool isUploaded = file != null;

    return InkWell(
      onTap: () => _pickImage(side),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200, // Fixed height for ID card look
        width: double.infinity,
        decoration: BoxDecoration(
          color: isUploaded ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          // Dashed border effect simulation
          border: isUploaded
              ? Border.all(color: AppColors.primaryBlue, width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1.5),
          image: isUploaded
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : null,
          boxShadow: [
            if (!isUploaded)
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: isUploaded
            ? Stack(
          children: [
            // Dark Overlay for text readability
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.black26,
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 24),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.primaryBlue.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              "Tap to upload $side",
              style: TextStyle(
                color: AppColors.primaryBlue.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}