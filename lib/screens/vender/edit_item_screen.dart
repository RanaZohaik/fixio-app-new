import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../constants/app_colors.dart';

class EditItemScreen extends StatefulWidget {
  final String             docId;
  final Map<String, dynamic> data;

  const EditItemScreen({super.key, required this.docId, required this.data});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;

  File?   _newImageFile;
  String? _currentImageUrl;
  bool    _isSaving = false;
  final   ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl       = TextEditingController(text: widget.data['title']);
    _descCtrl        = TextEditingController(text: widget.data['description']);
    _priceCtrl       = TextEditingController(
        text: widget.data['price'].toString());
    _currentImageUrl = widget.data['image'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String imageUrl = _currentImageUrl ?? '';

      if (_newImageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'items/${widget.docId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newImageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.docId)
          .update({
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price':       double.parse(_priceCtrl.text.trim()),
        'image':       imageUrl,
        'updatedAt':   FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text("Listing updated successfully!",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        title: const Text(
          'Edit Listing',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF1A1A2E), size: 16),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Image Section ──────────────────────────
              _SectionHeader(
                icon:  Icons.photo_camera_outlined,
                label: "Item Photo",
              ),
              const SizedBox(height: 12),
              _buildImagePicker(),

              const SizedBox(height: 28),

              // ── Info Section ───────────────────────────
              _SectionHeader(
                icon:  Icons.info_outline_rounded,
                label: "Listing Details",
              ),
              const SizedBox(height: 14),

              _buildField(
                controller: _titleCtrl,
                label:      'Item Title',
                hint:       'e.g. Professional Drill Machine',
                icon:       Icons.drive_file_rename_outline_rounded,
                validator:  (v) =>
                v!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _descCtrl,
                label:      'Description',
                hint:       'Describe condition, features, age...',
                icon:       Icons.notes_rounded,
                maxLines:   4,
                validator:  (v) =>
                v!.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _priceCtrl,
                label:      'Price (PKR)',
                hint:       '0.00',
                icon:       Icons.payments_outlined,
                inputType:  TextInputType.number,
                validator:  (v) =>
                double.tryParse(v ?? '') == null
                    ? 'Enter a valid price'
                    : null,
              ),

              const SizedBox(height: 36),

              // ── Save Button ────────────────────────────
              _buildSaveButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [

              // Image
              _newImageFile != null
                  ? Image.file(_newImageFile!, fit: BoxFit.cover)
                  : (_currentImageUrl != null &&
                  _currentImageUrl!.isNotEmpty
                  ? Image.network(_currentImageUrl!,
                  fit: BoxFit.cover)
                  : Container(color: const Color(0xFFF3F6FB))),

              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.45),
                    ],
                  ),
                ),
              ),

              // Tap hint
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.5),
                      ),
                      child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 24),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tap to change photo",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "JPG, PNG supported",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // New image indicator
              if (_newImageFile != null)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: Colors.white, size: 11),
                        SizedBox(width: 4),
                        Text(
                          "New photo",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    int                            maxLines  = 1,
    TextInputType                  inputType = TextInputType.text,
    String? Function(String?)?     validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller:    controller,
          maxLines:      maxLines,
          keyboardType:  inputType,
          validator:     validator,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF94A3B8).withOpacity(0.8),
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: AppColors.primaryBlue, size: 19),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            filled:          true,
            fillColor:       Colors.white,
            contentPadding:  const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          AppColors.primaryBlue.withOpacity(0.6),
          elevation:  0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          shadowColor: AppColors.primaryBlue.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(
          width:  22,
          height: 22,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.5),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              "Save Changes",
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:  32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w800,
            color:      Color(0xFF1A1A2E),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}