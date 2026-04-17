import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import '../../utils/icon_mapper.dart';
import '../../widgets/bottom_navbar.dart';
import '../../widgets/item_card_widget.dart'; // ← ADD THIS
import 'package:fixio/screens/vender/upload_item_screen.dart';
import '../home/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import 'category_items_screen.dart';
import 'item_detail_screen.dart';
import '../home/browse_page.dart'; // adjust path if needed
// home_screen.dart — add this import
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int    _currentIndex = 0;
  final  TextEditingController _searchCtrl     = TextEditingController();
  final  CategoryService       _categoryService = CategoryService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
          () => setState(
            () => _searchQuery = _searchCtrl.text.toLowerCase().trim(),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning ☀️";
    if (h < 17) return "Good Afternoon 🌤️";
    return "Good Evening 🌙";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:            Center(child: Text("Please Login")),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        final username = userSnap.data?.data()?['name'] ?? 'User';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _currentIndex == 3
                ? 2
                : _currentIndex == 4
                ? 3
                : _currentIndex,
            children: [
              _buildHomeContent(username),
              _buildBrowsePage(),
              _buildChatPage(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: FixioBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UploadItemScreen(),
                  ),
                );
              } else {
                setState(() => _currentIndex = index);
              }
            },
          ),
        );
      },
    );
  }

  // ── Home Content ──────────────────────────────────────────────────────────
  Widget _buildHomeContent(String username) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [

          // ── Greeting ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hi, $username",
                        style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.bold,
                          color:      AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          fontSize: 14,
                          color:    AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  _NotificationBell(),
                ],
              ),
            ),
          ),

          // ── Search Bar ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color:        AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.shadow,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search, color: AppColors.textSecondary),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                          color:    AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText:       "Search items or categories...",
                          hintStyle:      TextStyle(color: AppColors.textSecondary),
                          border:         InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size:  20,
                        ),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Categories Title ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Categories",
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "See All",
                      style: TextStyle(
                        color:      AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Categories Row ────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: StreamBuilder<List<CategoryModel>>(
                stream: _categoryService.getCategories(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snap.error}",
                        style: const TextStyle(
                          color:    Colors.red,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final cats = snap.data ?? [];
                  if (cats.isEmpty) {
                    return const Center(
                      child: Text(
                        "No categories.\nAdd in Firestore with isActive: true",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding:          const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection:  Axis.horizontal,
                    itemCount:        cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) => _CategoryChip(cat: cats[i]),
                  );
                },
              ),
            ),
          ),

          // ── Fresh Listings Title ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Fresh Listings",
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.bold,
                      color:      AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width:  8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        "Live",
                        style: TextStyle(
                          fontSize:   12,
                          color:      AppColors.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Items Grid ────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('items')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                return SliverToBoxAdapter(
                  child: _EmptyState(
                    icon:    Icons.error_outline,
                    color:   Colors.red,
                    message: "Permission denied.\nCheck your Firestore rules.",
                  ),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: _EmptyState(
                    icon:    Icons.inbox_outlined,
                    color:   AppColors.disabled,
                    message: "No items yet.\nTap + to list your first item!",
                  ),
                );
              }

              final all      = snap.data!.docs;
              final filtered = _searchQuery.isEmpty
                  ? all
                  : all.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final t = (d['title']        ?? '').toString().toLowerCase();
                final c = (d['categoryName'] ?? '').toString().toLowerCase();
                return t.contains(_searchQuery) ||
                    c.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: _EmptyState(
                    icon:    Icons.search_off,
                    color:   AppColors.disabled,
                    message: 'No results for "$_searchQuery"',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   2,
                    mainAxisSpacing:  14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.60, // ← updated to match ItemCardWidget
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      final data =
                      filtered[i].data() as Map<String, dynamic>;
                      return ItemCardWidget(       // ← REPLACED _ItemCard
                        data:  data,
                        docId: filtered[i].id,
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  // ── Placeholder Pages ─────────────────────────────────────────────────────
  Widget _buildBrowsePage() {
    return const BrowsePage();
  }

  Widget _buildChatPage() {
    return const ChatListScreen();
  }
}

// ── _NotificationBell ─────────────────────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.notifications_outlined,
              size:  22,
              color: AppColors.textPrimary,
            ),
            onPressed: () {},
          ),
        ),
        Positioned(
          right: 10,
          top:   10,
          child: Container(
            width:  8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── _CategoryChip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final CategoryModel cat;
  const _CategoryChip({required this.cat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryItemsScreen(
              categoryId:   cat.id,
              categoryName: cat.name,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  62,
            height: 62,
            decoration: BoxDecoration(
              color:        AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Icon(
              getIcon(cat.icon),
              color: AppColors.primaryBlue,
              size:  26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cat.name,
            style: const TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color:      AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _EmptyState ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   message;
  const _EmptyState({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:    AppColors.textSecondary,
              fontSize: 14,
              height:   1.6,
            ),
          ),
        ],
      ),
    );
  }
}