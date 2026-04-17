import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
// Ensure you have your AppColors imported, or use the colors defined below
import '../../constants/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController emailCtrl;

  File? pickedImage;
  bool isSaving = false; // Renamed for clarity

  final List<String> pakistanCities = [
    "Karachi", "Lahore", "Islamabad", "Rawalpindi",
    "Quetta", "Peshawar", "Multan", "Faisalabad",
    "Hyderabad", "Sialkot", "Gujranwala", "Sukkur",
    "Bahawalpur", "Sargodha", "Abbottabad"
  ];

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.userData['name']);
    phoneCtrl = TextEditingController(text: widget.userData['phone']);
    cityCtrl = TextEditingController(text: widget.userData['city']);
    emailCtrl = TextEditingController(text: widget.userData['email']);
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        pickedImage = File(picked.path);
      });
    }
  }

  Future<String?> uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_pictures/$uid.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text("Select City", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: pakistanCities.length,
                  itemBuilder: (_, index) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(pakistanCities[index]),
                      trailing: cityCtrl.text == pakistanCities[index]
                          ? const Icon(Icons.check_circle, color: AppColors.primaryBlue)
                          : null,
                      onTap: () {
                        setState(() {
                          cityCtrl.text = pakistanCities[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      String? profileUrl;
      if (pickedImage != null) {
        profileUrl = await uploadImage(pickedImage!);
      }

      final updateData = {
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        if (profileUrl != null) 'profileImage': profileUrl,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Light grey bg
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ===========================
              // 1. IMAGE UPLOADER
              // ===========================
              Center(
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: pickedImage != null
                            ? FileImage(pickedImage!)
                            : (widget.userData['profileImage'] != null
                            ? NetworkImage(widget.userData['profileImage'])
                            : const AssetImage('assets/profile_placeholder.png'))
                        as ImageProvider,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryBlue, Color(0xFF1A73E8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tap icon to change photo",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 30),

              // ===========================
              // 2. FORM FIELDS
              // ===========================
              _buildInputLabel("Full Name"),
              _buildTextField(
                controller: nameCtrl,
                hint: "Enter your name",
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 20),
              _buildInputLabel("Phone Number"),
              _buildTextField(
                controller: phoneCtrl,
                hint: "Enter your phone",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 20),
              _buildInputLabel("City"),
              GestureDetector(
                onTap: _showCityPicker,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: cityCtrl,
                    hint: "Select your city",
                    icon: Icons.location_city_outlined,
                    isDropdown: true,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildInputLabel("Email Address"),
              _buildTextField(
                controller: emailCtrl,
                hint: "Email",
                icon: Icons.email_outlined,
                isReadOnly: true,
              ),

              const SizedBox(height: 40),

              // ===========================
              // 3. SAVE BUTTON
              // ===========================
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF1A73E8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: isSaving
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widget for Labels
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  // Helper Widget for TextFields
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isReadOnly = false,
    bool isDropdown = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isReadOnly ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          if (!isReadOnly)
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: isReadOnly,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isReadOnly ? Colors.grey[600] : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        validator: (v) => v == null || v.isEmpty ? "This field is required" : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : AppColors.primaryBlue),
          suffixIcon: isDropdown
              ? const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.grey)
              : (isReadOnly ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey) : null),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none, // Removes default border for cleaner look
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          ),
          filled: true,
          fillColor: isReadOnly ? Colors.grey[100] : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}