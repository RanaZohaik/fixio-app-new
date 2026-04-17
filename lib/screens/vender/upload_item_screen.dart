import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../constants/app_colors.dart';
import '../../utils/icon_mapper.dart';

class UploadItemScreen extends StatefulWidget {
  const UploadItemScreen({super.key});

  @override
  State<UploadItemScreen> createState() => _UploadItemScreenState();
}

class _UploadItemScreenState extends State<UploadItemScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _titleCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _priceCtrl     = TextEditingController();
  final _locationCtrl  = TextEditingController();   // ← NEW
  final _phoneCtrl     = TextEditingController();   // ← NEW

  // ── Multiple images (max 3) ──────────────────────────────────────────────
  final List<File> _images    = [];
  final int        _maxImages = 3;

  bool    _isUploading    = false;
  double  _uploadProgress = 0.0;
  String? _selectedCategory;
  String? _selectedCondition;                        // ← NEW

  // ── Sell / Rent toggle ───────────────────────────────────────────────────
  String _listingType   = 'sell';
  String _rentDuration  = 'day';   // 'hour' | 'day' | 'week'

  final ImagePicker _picker = ImagePicker();

  // ── Condition options ────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _conditions = [   // ← NEW
    {"value": "New",        "icon": Icons.fiber_new_outlined},
    {"value": "Like New",   "icon": Icons.star_outline_rounded},
    {"value": "Good",       "icon": Icons.thumb_up_outlined},
    {"value": "Fair",       "icon": Icons.thumbs_up_down_outlined},
    {"value": "For Parts",  "icon": Icons.build_outlined},
  ];

  // ── Categories ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _categories = [
    {"id": "electronics", "name": "Electronics", "icon": "electronics"},
    {"id": "vehicles",    "name": "Vehicles",    "icon": "car"},
    {"id": "tools",       "name": "Tools",       "icon": "tools"},
    {"id": "furniture",   "name": "Furniture",   "icon": "chair"},
    {"id": "appliances",  "name": "Appliances",  "icon": "appliances"},
    {"id": "mobiles",     "name": "Mobiles",     "icon": "phone"},
    {"id": "fashion",     "name": "Fashion",     "icon": "fashion"},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();   // ← NEW
    _phoneCtrl.dispose();      // ← NEW
    super.dispose();
  }

  // ── Pick image ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_images.length >= _maxImages) {
      _showSnack("Maximum $_maxImages photos allowed");
      return;
    }
    final XFile? picked = await _picker.pickImage(
      source:       ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _images.add(File(picked.path)));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  // ── Upload ───────────────────────────────────────────────────────────────
  Future<void> _uploadItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _showSnack("Please add at least one photo");
      return;
    }
    if (_selectedCategory == null) {
      _showSnack("Please select a category");
      return;
    }
    if (_selectedCondition == null) {               // ← NEW
      _showSnack("Please select item condition");   // ← NEW
      return;                                        // ← NEW
    }

    setState(() {
      _isUploading    = true;
      _uploadProgress = 0.0;
    });

    try {
      final uid   = FirebaseAuth.instance.currentUser!.uid;
      final total = _images.length;
      final List<String> imageUrls = [];

      // ── Upload images ──────────────────────────────────────────────────
      for (int i = 0; i < total; i++) {
        final fileName   = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('items/$uid/$fileName');

        final uploadTask = storageRef.putFile(
          _images[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );

        uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
          final imageProgress = snap.bytesTransferred / snap.totalBytes;
          setState(() => _uploadProgress = (i + imageProgress) / total);
        });

        await uploadTask.whenComplete(() {});
        imageUrls.add(await storageRef.getDownloadURL());
      }

      // ── Fetch seller name from Firestore users collection ───────────── ← NEW
      String sellerName = 'Unknown Seller';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        sellerName = userDoc.data()?['name'] ?? 'Unknown Seller';
      } catch (_) {}

      final categoryName = _categories
          .firstWhere((c) => c['id'] == _selectedCategory)['name'];

      // ── Save to Firestore ───────────────────────────────────────────────
      await FirebaseFirestore.instance.collection('items').add({
        'title':        _titleCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'price':        double.parse(_priceCtrl.text.trim()),
        'image':        imageUrls.first,
        'images':       imageUrls,
        'vendorId':     uid,
        'categoryId':   _selectedCategory,
        'categoryName': categoryName,
        'listingType':  _listingType,
        'rentDuration': _listingType == 'rent' ? _rentDuration : null,
        'condition':    _selectedCondition,          // ← NEW
        'location':     _locationCtrl.text.trim(),   // ← NEW
        'sellerName':   sellerName,                  // ← NEW (auto-fetched)
        'phone':        _phoneCtrl.text.trim(),      // ← NEW
        'status':           'active',
        'verifiedVendor':   true,
        'createdAt':        FieldValue.serverTimestamp(),
      });

      _showSnack("Item listed successfully! ✅");
      _clearForm();
    } on FirebaseException catch (e) {
      _showSnack("Firebase error: ${e.message}");
    } catch (e) {
      _showSnack("Upload failed: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    setState(() {
      _images.clear();
      _selectedCategory  = null;
      _selectedCondition = null;
      _uploadProgress    = 0.0;
      _listingType       = 'sell';
      _rentDuration      = 'day';
    });
    _locationCtrl.clear();         // ← NEW
    _phoneCtrl.clear();            // ← NEW
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "List an Item",
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: AppColors.primaryBlue,
        iconTheme:       const IconThemeData(color: Colors.white),
        elevation:       0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primaryBlue,
                AppColors.accentOrange.withOpacity(0.7),
              ]),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero Banner ──────────────────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color:        AppColors.primaryBlue,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What are you listing?",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Add photos, details and publish in seconds",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Sell / Rent toggle
                  Container(
                    padding:      const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _toggleBtn(label: "🏷️  Sell", value: 'sell'),
                        _toggleBtn(label: "🔑  Rent", value: 'rent'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Photos ───────────────────────────────────────────
                    _sectionLabel("Photos", Icons.photo_library_outlined),
                    const SizedBox(height: 4),
                    Text(
                      "Add up to $_maxImages photos • First photo is the cover",
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._images.asMap().entries
                              .map((e) => _imageThumb(e.value, e.key)),
                          if (_images.length < _maxImages) _addPhotoButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Category ─────────────────────────────────────────
                    _sectionLabel("Category", Icons.grid_view_rounded),
                    const SizedBox(height: 12),
                    _buildCategoryChips(),

                    const SizedBox(height: 28),

                    // ── Condition ─────────────────────────────────────── ← NEW SECTION
                    _sectionLabel("Condition", Icons.auto_awesome_outlined),
                    const SizedBox(height: 12),
                    _buildConditionChips(),

                    const SizedBox(height: 28),

                    // ── Item Details ─────────────────────────────────────
                    _sectionLabel("Item Details", Icons.edit_note_rounded),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _titleCtrl,
                      label:     "Item Title",
                      hint:      "e.g. Honda Civic 2020",
                      icon:      Icons.title,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Enter a title"
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _descCtrl,
                      label:     "Description",
                      hint:      "Describe condition, age, features...",
                      icon:      Icons.description_outlined,
                      maxLines:  4,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Enter a description"
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _priceCtrl,
                      label: _listingType == 'sell'
                          ? "Price (Rs.)"
                          : _rentDuration == 'hour'
                          ? "Rent Price (Rs. / hour)"
                          : _rentDuration == 'week'
                          ? "Rent Price (Rs. / week)"
                          : "Rent Price (Rs. / day)",
                      hint:      "e.g. 15000",
                      icon:      Icons.payments_outlined,
                      inputType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return "Enter a price";
                        if (double.tryParse(v.trim()) == null)
                          return "Enter a valid number";
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── Rental Duration ──────────────────────────────── (rent only)
                    if (_listingType == 'rent') ...[
                      _sectionLabel("Rental Duration", Icons.schedule_outlined),
                      const SizedBox(height: 4),
                      const Text(
                        "How do you want to charge renters?",
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      _buildRentalDurationSelector(),
                      const SizedBox(height: 28),
                    ],
                    _sectionLabel(
                        "Contact & Location", Icons.person_pin_outlined),
                    const SizedBox(height: 4),
                    const Text(
                      "Buyers will see this on the item detail screen",
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    _buildField(
                      controller: _locationCtrl,
                      label:     "Location",
                      hint:      "e.g. Karachi, Lahore",
                      icon:      Icons.location_on_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Enter a location"
                          : null,
                    ),
                    const SizedBox(height: 14),

                    _buildField(
                      controller: _phoneCtrl,
                      label:     "Phone Number",
                      hint:      "e.g. 03001234567",
                      icon:      Icons.phone_outlined,
                      inputType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return "Enter your phone number";
                        if (v.trim().length < 10)
                          return "Enter a valid phone number";
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // ── Upload Progress ──────────────────────────────────
                    if (_isUploading) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Uploading ${_images.length} photo${_images.length > 1 ? 's' : ''}...",
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "${(_uploadProgress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value:           _uploadProgress,
                          minHeight:       8,
                          backgroundColor: AppColors.primaryBlueLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Submit Button ────────────────────────────────────
                    SizedBox(
                      width:  double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _listingType == 'sell'
                              ? AppColors.primaryBlue
                              : AppColors.accentOrange,
                          foregroundColor:         Colors.white,
                          disabledBackgroundColor: AppColors.disabled,
                          disabledForegroundColor: AppColors.disabledText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isUploading
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width:  20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Uploading ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_listingType == 'sell'
                                ? Icons.sell_outlined
                                : Icons.key_outlined),
                            const SizedBox(width: 10),
                            Text(
                              _listingType == 'sell'
                                  ? "List for Sale"
                                  : "List for Rent · Per ${_rentDuration[0].toUpperCase()}${_rentDuration.substring(1)}",
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rental Duration Selector ─────────────────────────────────────────────
  Widget _buildRentalDurationSelector() {
    final options = [
      {
        "value": "hour",
        "label": "Per Hour",
        "sub": "Great for tools & equipment",
        "icon": Icons.hourglass_bottom_rounded,
      },
      {
        "value": "day",
        "label": "Per Day",
        "sub": "Best for most rentals",
        "icon": Icons.wb_sunny_outlined,
      },
      {
        "value": "week",
        "label": "Per Week",
        "sub": "Long-term rentals",
        "icon": Icons.calendar_month_outlined,
      },
    ];

    return Column(
      children: options.map((opt) {
        final bool selected = _rentDuration == opt['value'];
        return GestureDetector(
          onTap: () => setState(() => _rentDuration = opt['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentOrange.withOpacity(0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.accentOrange : AppColors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color:      AppColors.accentOrange.withOpacity(0.15),
                  blurRadius: 10,
                  offset:     const Offset(0, 3),
                ),
              ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:  42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accentOrange
                        : AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    opt['icon'] as IconData,
                    size:  20,
                    color: selected ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 14),

                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt['label'] as String,
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.accentOrange
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt['sub'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color:    AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Radio dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:  22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.accentOrange
                        : AppColors.surface,
                    border: Border.all(
                      color: selected
                          ? AppColors.accentOrange
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                      size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Condition chips ───────────────────────────────────────────────────────
  Widget _buildConditionChips() {
    return Wrap(
      spacing:    10,
      runSpacing: 10,
      children: _conditions.map((cond) {
        final bool selected = _selectedCondition == cond['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCondition = cond['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBlue : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primaryBlue : AppColors.border,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color:      AppColors.primaryBlue.withOpacity(0.25),
                  blurRadius: 8,
                  offset:     const Offset(0, 3),
                ),
              ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cond['icon'] as IconData,
                  size:  15,
                  color: selected ? Colors.white : AppColors.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  cond['value'] as String,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sell / Rent toggle button ─────────────────────────────────────────────
  Widget _toggleBtn({required String label, required String value}) {
    final bool active = _listingType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _listingType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:  const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:        active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
              BoxShadow(
                color:      Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active
                  ? AppColors.primaryBlue
                  : Colors.white.withOpacity(0.8),
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontSize:   15,
            ),
          ),
        ),
      ),
    );
  }

  // ── Image thumbnail ───────────────────────────────────────────────────────
  Widget _imageThumb(File file, int index) {
    return Container(
      width:  110,
      height: 110,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: index == 0 ? AppColors.primaryBlue : AppColors.border,
          width: index == 0 ? 2 : 1,
        ),
        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          if (index == 0)
            Positioned(
              bottom: 6,
              left:   6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Cover",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            top:   5,
            right: 5,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width:  22,
                height: 22,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add photo button ──────────────────────────────────────────────────────
  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        width:  110,
        height: 110,
        decoration: BoxDecoration(
          color:        AppColors.primaryBlueLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                color: AppColors.primaryBlue, size: 30),
            const SizedBox(height: 6),
            Text(
              _images.isEmpty ? "Add Photo" : "Add More",
              style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              "${_images.length}/$_maxImages",
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Wrap(
      spacing:    10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final bool selected = _selectedCategory == cat['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBlue : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primaryBlue : AppColors.border,
                width: selected ? 0 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color:      AppColors.primaryBlue.withOpacity(0.25),
                  blurRadius: 8,
                  offset:     const Offset(0, 3),
                ),
              ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getIcon(cat['icon'] as String),
                  size:  16,
                  color: selected ? Colors.white : AppColors.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  cat['name'] as String,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width:  32,
          height: 32,
          decoration: BoxDecoration(
            color:        AppColors.primaryBlueLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold,
              color:      AppColors.textPrimary),
        ),
      ],
    );
  }

  // ── Text field builder ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    String? Function(String?)?     validator,
    TextInputType                  inputType = TextInputType.text,
    int                            maxLines  = 1,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: inputType,
      maxLines:     maxLines,
      enabled:      !_isUploading,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        hintStyle:  const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primaryBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: Colors.red),
        ),
        filled:    true,
        fillColor: AppColors.surface,
      ),
      validator: validator,
    );
  }
}