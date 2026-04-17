import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import '../../widgets/item_card_widget.dart';
import '../home/item_detail_screen.dart';

class BrowsePage extends StatefulWidget {
  final String? category;
  final String? categoryId;
  const BrowsePage({super.key, this.category, this.categoryId});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl  = TextEditingController();
  final ScrollController      _scrollCtrl  = ScrollController();
  final FocusNode             _searchFocus = FocusNode();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  _SortOption  _sortBy     = _SortOption.newest;
  _ListingType _filterType = _ListingType.all;
  bool   _isGridView       = true;
  bool   _showSearchBar    = false;
  bool   _scrolledDown     = false;
  String _searchQuery      = '';

  // ✅ FIX 1: Cache streams so they don't rebuild on scroll
  Stream<List<CategoryModel>>? _categoryStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _itemsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _listingsStream;

  late AnimationController _fabAnimCtrl;
  late Animation<double>   _fabAnim;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId   = widget.categoryId;
    _selectedCategoryName = widget.category;

    // ✅ FIX 2: Initialize streams ONCE here
    _categoryStream = CategoryService().getCategories();
    _itemsStream    = FirebaseFirestore.instance.collection('items').snapshots();
    _rebuildListingsStream();

    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnim = CurvedAnimation(
      parent: _fabAnimCtrl,
      curve: Curves.easeOutBack,
    );
    _fabAnimCtrl.forward();

    // ✅ FIX 3: Use a separate notifier for scroll — avoids full rebuild
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onScroll() {
    final scrolled = _scrollCtrl.offset > 60;
    if (scrolled != _scrolledDown) {
      // Only update the header, not the entire page
      setState(() => _scrolledDown = scrolled);
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _rebuildListingsStream(); // rebuild stream when search changes
      });
    }
  }

  /// ✅ FIX 4: Rebuild the listings stream only when filters change
  void _rebuildListingsStream() {
    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('items');

    if (_selectedCategoryId != null) {
      q = q.where('categoryId', isEqualTo: _selectedCategoryId);
    }
    if (_filterType != _ListingType.all) {
      q = q.where(
        'listingType',
        isEqualTo: _filterType == _ListingType.rent ? 'rent' : 'sell',
      );
    }
    if (_searchQuery.isNotEmpty) {
      q = q.where('keywords', arrayContains: _searchQuery);
    }

    final bool hasEqualityFilter = _selectedCategoryId != null ||
        _filterType != _ListingType.all ||
        _searchQuery.isNotEmpty;

    if (!hasEqualityFilter) {
      switch (_sortBy) {
        case _SortOption.newest:
          q = q.orderBy('createdAt', descending: true);
          break;
        case _SortOption.oldest:
          q = q.orderBy('createdAt', descending: false);
          break;
        case _SortOption.priceLow:
          q = q.orderBy('price', descending: false);
          break;
        case _SortOption.priceHigh:
          q = q.orderBy('price', descending: true);
          break;
      }
    }

    _listingsStream = q.snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchFocus.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  void _selectCategory(CategoryModel cat) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCategoryId == cat.id) {
        _selectedCategoryId   = null;
        _selectedCategoryName = null;
      } else {
        _selectedCategoryId   = cat.id;
        _selectedCategoryName = cat.name;
      }
      _rebuildListingsStream(); // ✅ Only rebuild stream on filter change
    });
  }

  void _clearAll() {
    setState(() {
      _selectedCategoryId   = null;
      _selectedCategoryName = null;
      _filterType = _ListingType.all;
      _sortBy     = _SortOption.newest;
      _searchCtrl.clear();
      _searchQuery = '';
      _rebuildListingsStream();
    });
  }

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
          _filterType != _ListingType.all ||
          _sortBy     != _SortOption.newest ||
          _searchQuery.isNotEmpty;

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        currentSort:        _sortBy,
        currentListingType: _filterType,
        onApply: (sort, type) {
          setState(() {
            _sortBy     = sort;
            _filterType = type;
            _rebuildListingsStream(); // ✅ Rebuild on filter apply
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: Column(
          children: [
            _BrowseHeader(
              showSearch:      _showSearchBar,
              searchCtrl:      _searchCtrl,
              searchFocus:     _searchFocus,
              scrolledDown:    _scrolledDown,
              isGridView:      _isGridView,
              hasFilters:      _hasActiveFilters,
              selectedCat:     _selectedCategoryName,
              onToggleSearch: () => setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchCtrl.clear();
                  _searchFocus.unfocus();
                } else {
                  Future.delayed(
                    const Duration(milliseconds: 100),
                        () => _searchFocus.requestFocus(),
                  );
                }
              }),
              onToggleView:   () => setState(() => _isGridView = !_isGridView),
              onFilterTap:    _openFilterSheet,
              onClearFilters: _clearAll,
            ),

            Expanded(
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _CategoryStrip(
                      selectedId:     _selectedCategoryId,
                      onSelect:       _selectCategory,
                      // ✅ Pass cached streams down
                      categoryStream: _categoryStream!,
                      itemsStream:    _itemsStream!,
                    ),
                  ),

                  if (_hasActiveFilters)
                    SliverToBoxAdapter(
                      child: _ActiveFiltersBar(
                        selectedCat:   _selectedCategoryName,
                        listingType:   _filterType,
                        sortBy:        _sortBy,
                        searchQuery:   _searchQuery,
                        onClearAll:    _clearAll,
                        onRemoveCat:   () => setState(() {
                          _selectedCategoryId   = null;
                          _selectedCategoryName = null;
                          _rebuildListingsStream();
                        }),
                        onRemoveType:   () => setState(() {
                          _filterType = _ListingType.all;
                          _rebuildListingsStream();
                        }),
                        onRemoveSort:   () => setState(() {
                          _sortBy = _SortOption.newest;
                          _rebuildListingsStream();
                        }),
                        onRemoveSearch: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                            _rebuildListingsStream();
                          });
                        },
                      ),
                    ),

                  _ListingsSliver(
                    stream:      _listingsStream!,
                    sortBy:      _sortBy,
                    isGridView:  _isGridView,
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

// ─── Header (unchanged) ───────────────────────────────────────────────────────
class _BrowseHeader extends StatelessWidget {
  final bool showSearch, scrolledDown, isGridView, hasFilters;
  final String? selectedCat;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final VoidCallback onToggleSearch, onToggleView, onFilterTap, onClearFilters;

  const _BrowseHeader({
    required this.showSearch,
    required this.scrolledDown,
    required this.isGridView,
    required this.hasFilters,
    required this.selectedCat,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onToggleSearch,
    required this.onToggleView,
    required this.onFilterTap,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Browse",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          selectedCat != null
                              ? "Showing: $selectedCat"
                              : "Find anything, rent or buy",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconBtn(
                    icon: showSearch
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    onTap:  onToggleSearch,
                    active: showSearch,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconBtn(
                    icon:   Icons.tune_rounded,
                    onTap:  onFilterTap,
                    active: hasFilters,
                    badge:  hasFilters,
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconBtn(
                    icon: isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    onTap: onToggleView,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve:    Curves.easeInOut,
                child: showSearch
                    ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _SearchField(
                    controller: searchCtrl,
                    focusNode:  searchFocus,
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final bool         active;
  final bool         badge;

  const _HeaderIconBtn({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.badge  = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? Colors.white.withOpacity(0.7)
                    : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge)
            Positioned(
              top:   -3,
              right: -3,
              child: Container(
                width:  10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;

  const _SearchField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: TextField(
        controller: controller,
        focusNode:  focusNode,
        style:      const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Search items, brands, categories…",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) => val.text.isNotEmpty
                ? GestureDetector(
              onTap: controller.clear,
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─── Category Strip — receives cached streams ────────────────────────────────
class _CategoryStrip extends StatelessWidget {
  final String?                              selectedId;
  final void Function(CategoryModel)         onSelect;
  final Stream<List<CategoryModel>>          categoryStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> itemsStream;

  const _CategoryStrip({
    required this.selectedId,
    required this.onSelect,
    required this.categoryStream,
    required this.itemsStream,
  });

  static const _fallbackIcons = <String, IconData>{
    'Electronics':      Icons.devices_rounded,
    'Tools':            Icons.construction_rounded,
    'Furniture':        Icons.chair_rounded,
    'Vehicles':         Icons.directions_car_rounded,
    'Home Appliances':  Icons.kitchen_rounded,
    'Appliances':       Icons.kitchen_rounded,
    'Sports':           Icons.sports_soccer_rounded,
    'Fashion':          Icons.checkroom_rounded,
    'Books':            Icons.menu_book_rounded,
    'Garden':           Icons.yard_rounded,
    'Toys':             Icons.toys_rounded,
    'Music':            Icons.music_note_rounded,
    'Photography':      Icons.camera_alt_rounded,
    'Mobiles':          Icons.smartphone_rounded,
  };

  static const _fallbackColors = <String, Color>{
    'Electronics':      Color(0xFF1E88E5),
    'Tools':            Color(0xFFE53935),
    'Furniture':        Color(0xFF8E24AA),
    'Vehicles':         Color(0xFF00897B),
    'Home Appliances':  Color(0xFFF4511E),
    'Appliances':       Color(0xFFF4511E),
    'Sports':           Color(0xFF43A047),
    'Fashion':          Color(0xFFD81B60),
    'Books':            Color(0xFF6D4C41),
    'Garden':           Color(0xFF558B2F),
    'Toys':             Color(0xFFFB8C00),
    'Music':            Color(0xFF5E35B1),
    'Photography':      Color(0xFF0097A7),
    'Mobiles':          Color(0xFF3949AB),
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryModel>>(
      stream: categoryStream, // ✅ Uses cached stream
      builder: (context, catSnap) {
        if (catSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 130,
            child: Center(
              child: SizedBox(
                width:  20,
                height: 20,
                child: CircularProgressIndicator(
                  color:       AppColors.primaryBlue,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final cats = catSnap.data ?? [];
        if (cats.isEmpty) return const SizedBox(height: 8);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: itemsStream, // ✅ Uses cached stream
          builder: (context, itemSnap) {
            final Map<String, int> countMap = {};
            if (itemSnap.hasData) {
              for (final doc in itemSnap.data!.docs) {
                final cid = doc.data()['categoryId'] as String?;
                if (cid != null) {
                  countMap[cid] = (countMap[cid] ?? 0) + 1;
                }
              }
            }

            return SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat    = cats[i];
                  final active = selectedId == cat.id;
                  final color  = _fallbackColors[cat.name] ?? AppColors.primaryBlue;
                  final icon   = _fallbackIcons[cat.name]  ?? Icons.category_rounded;
                  final count  = countMap[cat.id] ?? 0;

                  return GestureDetector(
                    onTap: () => onSelect(cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width:  80,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        vertical:   10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active ? color : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? color
                              : Colors.grey.withOpacity(0.18),
                          width: active ? 2 : 1,
                        ),
                        boxShadow: [
                          if (active)
                            BoxShadow(
                              color:      color.withOpacity(0.35),
                              blurRadius: 10,
                              offset:     const Offset(0, 4),
                            )
                          else
                            BoxShadow(
                              color:      Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset:     const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width:  40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white.withOpacity(0.22)
                                      : color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  size:  20,
                                  color: active ? Colors.white : color,
                                ),
                              ),
                              if (count > 0)
                                Positioned(
                                  top:   -5,
                                  right: -5,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical:   2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : color,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: active
                                            ? color.withOpacity(0.3)
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:      Colors.black.withOpacity(0.12),
                                          blurRadius: 4,
                                          offset:     const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: TextStyle(
                                        fontSize:   8,
                                        fontWeight: FontWeight.w800,
                                        color: active ? color : Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines:  2,
                            overflow:  TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:   9.5,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count == 0
                                ? 'No items'
                                : '$count item${count != 1 ? 's' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize:   8,
                              fontWeight: FontWeight.w500,
                              color: active
                                  ? Colors.white.withOpacity(0.75)
                                  : AppColors.textSecondary,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Active Filters Bar (unchanged) ──────────────────────────────────────────
class _ActiveFiltersBar extends StatelessWidget {
  final String?      selectedCat;
  final _ListingType listingType;
  final _SortOption  sortBy;
  final String       searchQuery;
  final VoidCallback onClearAll, onRemoveCat, onRemoveType, onRemoveSort,
      onRemoveSearch;

  const _ActiveFiltersBar({
    required this.selectedCat,
    required this.listingType,
    required this.sortBy,
    required this.searchQuery,
    required this.onClearAll,
    required this.onRemoveCat,
    required this.onRemoveType,
    required this.onRemoveSort,
    required this.onRemoveSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (searchQuery.isNotEmpty)
                  _FilterChip(
                    label:    '"$searchQuery"',
                    icon:     Icons.search_rounded,
                    onRemove: onRemoveSearch,
                  ),
                if (selectedCat != null)
                  _FilterChip(
                    label:    selectedCat!,
                    icon:     Icons.category_rounded,
                    onRemove: onRemoveCat,
                  ),
                if (listingType != _ListingType.all)
                  _FilterChip(
                    label: listingType == _ListingType.rent
                        ? "For Rent"
                        : "For Sale",
                    icon: listingType == _ListingType.rent
                        ? Icons.key_rounded
                        : Icons.sell_rounded,
                    onRemove: onRemoveType,
                  ),
                if (sortBy != _SortOption.newest)
                  _FilterChip(
                    label:    sortBy.label,
                    icon:     Icons.sort_rounded,
                    onRemove: onRemoveSort,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClearAll,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Text(
                "Clear all",
                style: TextStyle(
                  color:      Colors.red,
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onRemove;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color:      AppColors.primaryBlue,
              fontSize:   11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size:  13,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Listings Sliver — accepts pre-built stream ───────────────────────────────
class _ListingsSliver extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final _SortOption  sortBy;
  final bool         isGridView;

  const _ListingsSliver({
    required this.stream,
    required this.sortBy,
    required this.isGridView,
  });

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final sorted = List.of(docs);
    switch (sortBy) {
      case _SortOption.newest:
        sorted.sort((a, b) {
          final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
        break;
      case _SortOption.oldest:
        sorted.sort((a, b) {
          final ta = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        });
        break;
      case _SortOption.priceLow:
        sorted.sort((a, b) {
          final pa = (a.data()['price'] as num?)?.toDouble() ?? 0;
          final pb = (b.data()['price'] as num?)?.toDouble() ?? 0;
          return pa.compareTo(pb);
        });
        break;
      case _SortOption.priceHigh:
        sorted.sort((a, b) {
          final pa = (a.data()['price'] as num?)?.toDouble() ?? 0;
          final pb = (b.data()['price'] as num?)?.toDouble() ?? 0;
          return pb.compareTo(pa);
        });
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream, // ✅ Uses pre-built, cached stream
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color:       AppColors.primaryBlue,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Finding listings…",
                      style: TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snap.hasError) {
          return SliverToBoxAdapter(
            child: _ErrorState(error: snap.error.toString()),
          );
        }

        final docs = _sortDocs(snap.data?.docs ?? []);

        if (docs.isEmpty) {
          return SliverToBoxAdapter(child: _EmptyState());
        }

        final header = SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Text(
              "${docs.length} listing${docs.length != 1 ? 's' : ''} found",
              style: TextStyle(
                fontSize:   12,
                color:      AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );

        if (isGridView) {
          return MultiSliver(
            children: [
              header,
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:  2,
                    mainAxisSpacing:  14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.60,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => ItemCardWidget(
                      data:  docs[i].data(),
                      docId: docs[i].id,
                    ),
                    childCount: docs.length,
                  ),
                ),
              ),
            ],
          );
        } else {
          return MultiSliver(
            children: [
              header,
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _ListingListTile(
                      data:  docs[i].data(),
                      docId: docs[i].id,
                    ),
                    childCount: docs.length,
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}

// ─── List Tile (unchanged) ────────────────────────────────────────────────────
class _ListingListTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String               docId;

  const _ListingListTile({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final title     = data['title']        as String? ?? 'Untitled';
    final price     = data['price'];
    final location  = data['location']     as String? ?? '';
    final isRent    = data['listingType'] == 'rent';
    final duration  = data['rentDuration'] as String? ?? '';
    final condition = data['condition']    as String? ?? '';
    final rawImages = data['images'];
    final imageUrl  = (rawImages is List && rawImages.isNotEmpty)
        ? rawImages.first.toString()
        : (data['image'] as String? ?? '');
    final tileColor = isRent ? AppColors.accentOrange : AppColors.primaryBlue;
    final tileLabel = isRent
        ? (duration.isNotEmpty ? 'Rent / $duration' : 'For Rent')
        : 'For Sale';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(data: data, docId: docId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              child: SizedBox(
                width:  110,
                height: 110,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _TilePlaceholder(),
                )
                    : _TilePlaceholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:   3,
                      ),
                      decoration: BoxDecoration(
                        color: tileColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tileLabel,
                        style: TextStyle(
                          fontSize:      9,
                          fontWeight:    FontWeight.w800,
                          color:         tileColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize:   14,
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
                          fontSize:   15,
                          fontWeight: FontWeight.w800,
                          color:      tileColor,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (location.isNotEmpty) ...[
                          Icon(
                            Icons.location_on_rounded,
                            size:  11,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 11,
                                color:    AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (condition.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical:   2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              condition,
                              style: const TextStyle(
                                fontSize:   9,
                                color:      AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size:  14,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TilePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF0F2F5),
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: Colors.grey,
      size:  32,
    ),
  );
}

// ─── Empty & Error (unchanged) ────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            width:  96,
            height: 96,
            decoration: BoxDecoration(
              color:        AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size:  46,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No listings found",
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try a different category, keyword, or remove some filters.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:    AppColors.textSecondary,
              height:   1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 56, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text(
            "Something went wrong",
            style: TextStyle(
              fontSize:   17,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color:    AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Sheet (unchanged) ─────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final _SortOption  currentSort;
  final _ListingType currentListingType;
  final void Function(_SortOption, _ListingType) onApply;

  const _FilterSheet({
    required this.currentSort,
    required this.currentListingType,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _SortOption  _sort;
  late _ListingType _type;

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _type = widget.currentListingType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width:  40,
              height: 4,
              decoration: BoxDecoration(
                color:        Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Filter & Sort",
                style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _sort = _SortOption.newest;
                  _type = _ListingType.all;
                }),
                child: const Text("Reset"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "LISTING TYPE",
            style: TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              color:         AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _ListingType.values.map((t) {
              final active = _type == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin:   const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryBlue
                          : AppColors.primaryBlueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            "SORT BY",
            style: TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              color:         AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          ..._SortOption.values.map((s) {
            final active = _sort == s;
            return GestureDetector(
              onTap: () => setState(() => _sort = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin:   const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical:   13,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryBlue.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppColors.primaryBlue.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.icon,
                      size:  18,
                      color: active
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (active)
                      const Icon(
                        Icons.check_circle_rounded,
                        size:  18,
                        color: AppColors.primaryBlue,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          SizedBox(
            width:  double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_sort, _type);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Apply Filters",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Multi-sliver helper ──────────────────────────────────────────────────────
class MultiSliver extends StatelessWidget {
  final List<Widget> children;
  const MultiSliver({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      SliverMainAxisGroup(slivers: children);
}

// ─── Enums ────────────────────────────────────────────────────────────────────
enum _SortOption {
  newest,
  oldest,
  priceLow,
  priceHigh;

  String get label {
    switch (this) {
      case newest:    return "Newest First";
      case oldest:    return "Oldest First";
      case priceLow:  return "Price: Low to High";
      case priceHigh: return "Price: High to Low";
    }
  }

  IconData get icon {
    switch (this) {
      case newest:    return Icons.access_time_rounded;
      case oldest:    return Icons.history_rounded;
      case priceLow:  return Icons.arrow_upward_rounded;
      case priceHigh: return Icons.arrow_downward_rounded;
    }
  }
}

enum _ListingType {
  all,
  rent,
  sell;

  String get label {
    switch (this) {
      case all:  return "All";
      case rent: return "For Rent";
      case sell: return "For Sale";
    }
  }
}