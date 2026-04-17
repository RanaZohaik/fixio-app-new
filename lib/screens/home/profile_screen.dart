import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixio/constants/app_colors.dart';
import 'package:fixio/routes/app_routes.dart';
import 'package:fixio/screens/home/edit_profile_screen.dart';
import 'package:fixio/screens/home/item_detail_screen.dart';
import 'package:fixio/services/firebase_auth_service.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? user;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        setState(() => user = UserModel.fromDocument(doc));
      }
    });
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmDialog(
      title:   "Log Out",
      message: "Are you sure you want to log out?",
      confirmText: "Log Out",
      confirmColor: Colors.redAccent,
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  // ----------------------------------------------------------------
  // Quick avatar re-upload from Profile Screen
  // ----------------------------------------------------------------
  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;

    final pickedFile = await ImagePicker().pickImage(
      source:       source,
      imageQuality: 70,
      maxWidth:     800,
      maxHeight:    800,
    );
    if (pickedFile == null || !mounted) return;

    _showLoadingDialog("Updating photo…");

    final error = await FirebaseAuthService().updateProfile(
      name:             user?.name ?? '',
      phone:            user?.phone ?? '',
      city:             user?.city ?? '',
      profileImageFile: File(pickedFile.path),
    );

    if (!mounted) return;
    Navigator.pop(context); // dismiss loader

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack("Profile photo updated!");
    }
  }

  // ----------------------------------------------------------------
  // Delete Account
  // ----------------------------------------------------------------
  Future<void> _deleteAccount() async {
    final password = await _showPasswordDialog(
      title:   "Delete Account",
      message: "This will permanently delete your account and all data. This action cannot be undone.",
      actionLabel: "Delete My Account",
      actionColor: Colors.red,
    );
    if (password == null) return;

    _showLoadingDialog("Deleting account…");

    final error = await FirebaseAuthService().deleteAccount(password: password);

    if (!mounted) return;
    Navigator.pop(context);

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  // ----------------------------------------------------------------
  // Disable Account
  // ----------------------------------------------------------------
  Future<void> _disableAccount() async {
    final password = await _showPasswordDialog(
      title:       "Disable Account",
      message:     "Your account will be hidden and you will be signed out. Contact support to reactivate.",
      actionLabel: "Disable Account",
      actionColor: Colors.orange,
    );
    if (password == null) return;

    _showLoadingDialog("Disabling account…");

    final error = await FirebaseAuthService().disableAccount(password: password);

    if (!mounted) return;
    Navigator.pop(context);

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.login, (_) => false);
    }
  }

  // ----------------------------------------------------------------
  // Dialogs & Helpers
  // ----------------------------------------------------------------
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color  confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:   Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String message,
    required String actionLabel,
    required Color  actionColor,
  }) async {
    final ctrl = TextEditingController();
    bool obscure = true;
    String? inputError;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller:   ctrl,
                obscureText:  obscure,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  errorText: inputError,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) {
                  setS(() => inputError = "Enter your password");
                  return;
                }
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: Text(actionLabel,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? Colors.redAccent : AppColors.successGreen,
        behavior:        SnackBarBehavior.floating,
        shape:           RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAccountActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountActionsSheet(
        onDisable: _disableAccount,
        onDelete:  _deleteAccount,
      ),
    );
  }

  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isVendor     = user?.role == "vendor";
    final profileImage = user?.profileImage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(
                top: 50, bottom: 0, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, Color(0xFF1A73E8)],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Profile",
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showAccountActionsSheet,
                          icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white),
                          tooltip: "Account Actions",
                        ),
                        IconButton(
                          onPressed: () {
                            if (user != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                      userData: user!.toMap()),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Avatar + name row
                Row(
                  children: [
                    GestureDetector(
                      onTap: _changeAvatar,
                      child: Stack(
                        children: [
                          Container(
                            padding:    const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundImage: profileImage != null
                                  ? NetworkImage(profileImage) as ImageProvider
                                  : const AssetImage(
                                  'assets/profile_placeholder.png'),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right:  2,
                            child: Container(
                              padding:    const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color:  Colors.white,
                                shape:  BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size:  11,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? "Loading…",
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? "",
                            style: TextStyle(
                              color:    Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVendor
                                  ? Colors.purpleAccent.withOpacity(0.2)
                                  : Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isVendor ? "Vendor" : "Buyer",
                              style: TextStyle(
                                color: isVendor
                                    ? Colors.purpleAccent
                                    : Colors.greenAccent,
                                fontSize:   12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick stats
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                          "4.8", "Rating",
                          Icons.star_rounded, Colors.amber),
                      _buildDivider(),
                      _buildStatItem(
                          "12", "Orders",
                          Icons.shopping_bag_rounded, Colors.blueAccent),
                      _buildDivider(),
                      _buildStatItem(
                          user?.city ?? "—", "City",
                          Icons.location_on_rounded, Colors.greenAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab bar
                TabBar(
                  controller:         _tabController,
                  indicatorColor:     Colors.white,
                  indicatorWeight:    3,
                  indicatorSize:      TabBarIndicatorSize.label,
                  labelColor:         Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: "Account"),
                    Tab(text: "Favorites"),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Views ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AccountTab(
                  user:     user,
                  isVendor: isVendor,
                  onLogout: _logout,
                  onEdit: () {
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditProfileScreen(userData: user!.toMap()),
                        ),
                      );
                    }
                  },
                ),
                _FavoritesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.65), fontSize: 11)),
      ],
    );
  }

  Widget _buildDivider() => Container(
    height: 30,
    width:  1,
    color:  Colors.white.withOpacity(0.2),
  );
}

// ── Account Tab ───────────────────────────────────────────────────────────────
class _AccountTab extends StatelessWidget {
  final UserModel?   user;
  final bool         isVendor;
  final VoidCallback onLogout;
  final VoidCallback onEdit;

  const _AccountTab({
    required this.user,
    required this.isVendor,
    required this.onLogout,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isVendor) ...[
            _buildSectionTitle("Vendor Zone"),
            _buildMenuCard([
              _buildMenuItem(
                  "Create Listing", Icons.add_circle_rounded, Colors.purple,
                      () {}),
              _buildMenuItem(
                  "Manage Listings", Icons.storefront_rounded, Colors.purple,
                      () {}),
            ]),
            const SizedBox(height: 20),
          ],

          _buildSectionTitle("General"),
          _buildMenuCard([
            _buildMenuItem(
                "Rental History", Icons.history_rounded, Colors.blue, () {}),
            _buildMenuItem(
                "Messages", Icons.chat_bubble_rounded, Colors.orange, () {}),
          ]),

          const SizedBox(height: 20),
          _buildSectionTitle("Settings"),
          _buildMenuCard([
            _buildMenuItem(
                "Edit Profile", Icons.person_rounded, Colors.teal, onEdit),
            _buildMenuItem(
                "Notifications", Icons.notifications_rounded, Colors.indigo,
                    () {}),
            _buildMenuItem(
                "Privacy Policy", Icons.lock_rounded, Colors.grey, () {}),
          ]),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                elevation:       0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                      color: Colors.redAccent.withOpacity(0.25)),
                ),
              ),
              child: const Text("Log Out",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 10),
    child: Text(
      title,
      style: TextStyle(
        fontSize:      14,
        fontWeight:    FontWeight.bold,
        color:         Colors.grey[600],
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _buildMenuCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color:        Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color:     Colors.black.withOpacity(0.03),
          blurRadius: 15,
          offset:    const Offset(0, 5),
        ),
      ],
    ),
    child: Column(children: children),
  );

  Widget _buildMenuItem(
      String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                padding:    const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w600,
                    color:      Color(0xFF2D3142),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 15, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Favorites Tab ─────────────────────────────────────────────────────────────
class _FavoritesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text("Not signed in"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color:        AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size:  52,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No favorites yet",
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Items you save will appear here",
                  style: TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding:     const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   2,
            mainAxisSpacing:  12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = {...docs[index].data() as Map<String, dynamic>};
            final docId = docs[index].id;
            data['id'] = docId;
            return _FavoriteCard(
              data:  data,
              docId: docId,
              uid:   uid,
            );
          },
        );
      },
    );
  }
}

// ── Favorite Card ─────────────────────────────────────────────────────────────
class _FavoriteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String               docId;
  final String               uid;

  const _FavoriteCard({
    required this.data,
    required this.docId,
    required this.uid,
  });

  Future<void> _removeFavorite(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(docId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Removed from favorites",
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.grey[700],
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title    = data['title']    as String? ?? 'Untitled';
    final price    = data['price'];
    final image    = data['image']    as String? ?? '';
    final images   = data['images'];
    final thumbUrl = (images is List && images.isNotEmpty)
        ? images.first.toString()
        : image;
    final isRent   = data['listingType'] == 'rent';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(data: data, docId: docId),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:     Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset:    const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                    child: thumbUrl.isNotEmpty
                        ? Image.network(
                      thumbUrl,
                      fit:          BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _NoImage(),
                    )
                        : _NoImage(),
                  ),
                  // Listing type badge
                  Positioned(
                    top:  8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRent
                            ? AppColors.accentOrange
                            : AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRent ? "Rent" : "Sale",
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  // Remove button
                  Positioned(
                    top:   8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          shape:        BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:     Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.redAccent,
                          size:  14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.textPrimary,
                    ),
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (price != null)
                    Text(
                      "Rs. $price",
                      style: TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w800,
                        color: isRent
                            ? AppColors.accentOrange
                            : AppColors.primaryBlue,
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
}

class _NoImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF0F2F5),
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Colors.grey,
      size:  36,
    ),
  );
}

// ── Account Actions Bottom Sheet ──────────────────────────────────────────────
class _AccountActionsSheet extends StatelessWidget {
  final VoidCallback onDisable;
  final VoidCallback onDelete;

  const _AccountActionsSheet({
    required this.onDisable,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  36,
            height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Account Actions",
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "These actions affect your account access",
            style: TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),

          // Disable Account
          _ActionTile(
            icon:        Icons.pause_circle_outline_rounded,
            iconColor:   Colors.orange,
            title:       "Disable Account",
            subtitle:    "Temporarily hide your account. Contact support to re-enable.",
            onTap: () {
              Navigator.pop(context);
              onDisable();
            },
          ),
          const Divider(height: 1),

          // Delete Account
          _ActionTile(
            icon:        Icons.delete_forever_rounded,
            iconColor:   Colors.red,
            title:       "Delete Account",
            subtitle:    "Permanently delete all data. This cannot be undone.",
            titleColor:  Colors.red,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     title;
  final String     subtitle;
  final Color?     titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding:    const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color:    AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// ── Image Source Sheet ────────────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  36,
            height: 4,
            decoration: BoxDecoration(
              color:        Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Change Photo",
            style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SourceOption(
                icon:  Icons.photo_library_rounded,
                label: "Gallery",
                color: AppColors.primaryBlue,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              _SourceOption(
                icon:  Icons.camera_alt_rounded,
                label: "Camera",
                color: AppColors.accentOrange,
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
  final Color        color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width:  70,
            height: 70,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                color:      Colors.grey[600],
                fontSize:   13,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}