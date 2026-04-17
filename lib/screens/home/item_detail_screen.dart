import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/chat_service.dart';
import '../chat/chat_room_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? docId;

  const ItemDetailScreen({super.key, required this.data, this.docId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _slideUp;

  final _pageCtrl = PageController();
  int _currentImageIndex = 0;
  late List<String> _images;

  final String _myId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _svc         = ChatService();

  @override
  void initState() {
    super.initState();

    final rawImages = widget.data['images'];
    if (rawImages is List && rawImages.isNotEmpty) {
      _images = rawImages.map((e) => e.toString()).toList();
    } else {
      final single = widget.data['image'] as String? ?? '';
      _images = single.isNotEmpty ? [single] : [];
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  String get _docId => widget.docId ?? widget.data['id']?.toString() ?? '';

  void _toggleFavorite() {
    if (_docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save — item ID missing')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    _svc.toggleFavorite(_docId, widget.data);
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(data: widget.data),
    );
  }

  void _showContactDialog(String phone, String name) {
    showDialog(
      context: context,
      builder: (_) => _ContactDialog(phone: phone, sellerName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data         = widget.data;
    final title        = data['title']        as String? ?? 'Untitled';
    final price        = data['price'];
    final categoryName = data['categoryName'] as String? ?? '';
    final description  = data['description']  as String?
        ?? 'No description provided by the seller.';
    final condition    = data['condition']    as String? ?? '';
    final location     = data['location']     as String? ?? '';
    final sellerName   = data['sellerName']   as String? ?? 'Unknown Seller';
    final sellerPhone  = data['phone']        as String? ?? '';
    final sellerAvatar = data['sellerAvatar'] as String? ?? '';
    final listingType  = data['listingType']  as String? ?? 'sell';
    final rentDuration = data['rentDuration'] as String? ?? '';
    final vendorId     = data['vendorId']     as String? ?? '';
    final postedDate   = data['createdAt'];

    final bool   isRent        = listingType == 'rent';
    final String durationLabel =
    rentDuration.isNotEmpty ? '/ $rentDuration' : '';
    final bool isOwnListing =
        vendorId.isNotEmpty && vendorId == _myId;

    String formattedDate = '';
    if (postedDate != null) {
      try {
        final dt = (postedDate as dynamic).toDate() as DateTime;
        formattedDate = '${dt.day} ${_monthName(dt.month)}, ${dt.year}';
      } catch (_) {}
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Scrollable Content ──────────────────────────────────────
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero Image / Carousel AppBar ────────────────────────
                SliverAppBar(
                  expandedHeight: 360,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image carousel
                        _images.isEmpty
                            ? _ImagePlaceholder()
                            : PageView.builder(
                          controller: _pageCtrl,
                          onPageChanged: (i) =>
                              setState(() => _currentImageIndex = i),
                          itemCount: _images.length,
                          itemBuilder: (_, i) => Image.network(
                            _images[i],
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return _ImagePlaceholder();
                            },
                            errorBuilder: (_, __, ___) =>
                                _ImagePlaceholder(),
                          ),
                        ),

                        // Bottom fade
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.28),
                                  Colors.transparent,
                                  AppColors.background,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // Top fade for buttons
                        Positioned(
                          top: 0, left: 0, right: 0,
                          height: 120,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.45),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Dot indicators
                        if (_images.length > 1)
                          Positioned(
                            bottom: 28,
                            left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _images.length,
                                    (i) => AnimatedContainer(
                                  duration:
                                  const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3),
                                  width:
                                  i == _currentImageIndex ? 20 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i == _currentImageIndex
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                    borderRadius:
                                    BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Image counter badge
                        if (_images.length > 1)
                          Positioned(
                            top: 80, right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.photo_library_outlined,
                                      size: 12,
                                      color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentImageIndex + 1}/${_images.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Listing type badge
                        Positioned(
                          bottom: _images.length > 1 ? 52 : 20,
                          right: 20,
                          child: _ListingTypeBadge(
                            isRent: isRent,
                            durationLabel: durationLabel,
                          ),
                        ),

                        // Condition badge
                        if (condition.isNotEmpty)
                          Positioned(
                            bottom: _images.length > 1 ? 52 : 20,
                            left: 20,
                            child: _GlassBadge(label: condition),
                          ),

                        // "Your listing" badge
                        if (isOwnListing)
                          Positioned(
                            top: 80,
                            left: 0, right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_rounded,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Your Listing',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Main Detail Content ─────────────────────────────────
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, 0, 20, isOwnListing ? 40 : 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (categoryName.isNotEmpty) ...[
                                  _CategoryPill(label: categoryName),
                                  const SizedBox(width: 8),
                                ],
                                _ListingTypePill(
                                  isRent: isRent,
                                  durationLabel: durationLabel,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              crossAxisAlignment:
                              CrossAxisAlignment.center,
                              children: [
                                if (price != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentOrange
                                          .withOpacity(0.12),
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                      textBaseline:
                                      TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          'Rs. $price',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color:
                                            AppColors.accentOrange,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        if (isRent &&
                                            durationLabel
                                                .isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            durationLabel,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors
                                                  .accentOrange
                                                  .withOpacity(0.75),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                if (formattedDate.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 13,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            _SectionDivider(label: 'Description'),
                            const SizedBox(height: 12),

                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: AppColors.textSecondary,
                                height: 1.75,
                                letterSpacing: 0.1,
                              ),
                            ),

                            const SizedBox(height: 24),
                            _SectionDivider(label: 'Item Details'),
                            const SizedBox(height: 16),

                            _InfoGrid(
                              items: [
                                _InfoItem(
                                  icon: isRent
                                      ? Icons.key_outlined
                                      : Icons.sell_outlined,
                                  label: 'Listing Type',
                                  value: isRent
                                      ? (durationLabel.isNotEmpty
                                      ? 'Rent $durationLabel'
                                      : 'For Rent')
                                      : 'For Sale',
                                  accentColor: isRent
                                      ? AppColors.accentOrange
                                      : AppColors.successGreen,
                                ),
                                if (condition.isNotEmpty)
                                  _InfoItem(
                                    icon: Icons.auto_awesome_outlined,
                                    label: 'Condition',
                                    value: condition,
                                  ),
                                if (location.isNotEmpty)
                                  _InfoItem(
                                    icon: Icons.location_on_outlined,
                                    label: 'Location',
                                    value: location,
                                  ),
                                if (categoryName.isNotEmpty)
                                  _InfoItem(
                                    icon: Icons.category_outlined,
                                    label: 'Category',
                                    value: categoryName,
                                  ),
                                if (price != null)
                                  _InfoItem(
                                    icon: Icons.payments_outlined,
                                    label: isRent
                                        ? 'Rent Price'
                                        : 'Sale Price',
                                    value: isRent &&
                                        durationLabel.isNotEmpty
                                        ? 'Rs. $price $durationLabel'
                                        : 'Rs. $price',
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),
                            _SectionDivider(label: 'Seller Information'),
                            const SizedBox(height: 16),

                            _SellerCard(
                              name:      sellerName,
                              phone:     sellerPhone,
                              avatarUrl: sellerAvatar,
                              location:  location,
                              onContactTap: sellerPhone.isNotEmpty
                                  ? () => _showContactDialog(
                                  sellerPhone, sellerName)
                                  : null,
                            ),

                            // Chat card
                            if (!isOwnListing && vendorId.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _ChatWithVendorCard(
                                sellerName:   sellerName,
                                sellerAvatar: sellerAvatar,
                                vendorId:     vendorId,
                                isRent:       isRent,
                                itemData:     data,
                              ),
                            ],

                            // Own listing notice
                            if (isOwnListing) ...[
                              const SizedBox(height: 16),
                              _OwnListingNotice(isRent: isRent),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating Top Buttons ────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FloatingIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        _docId.isNotEmpty
                            ? StreamBuilder<bool>(
                          stream: _svc.isFavoriteStream(_docId),
                          builder: (ctx, snap) {
                            final isFav = snap.data ?? false;
                            return _FloatingIconBtn(
                              icon: isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              iconColor:
                              isFav ? Colors.red : null,
                              onTap: _toggleFavorite,
                            );
                          },
                        )
                            : _FloatingIconBtn(
                          icon: Icons.favorite_border_rounded,
                          onTap: _toggleFavorite,
                        ),
                        const SizedBox(width: 10),
                        _FloatingIconBtn(
                          icon: Icons.share_outlined,
                          onTap: _showShareSheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Bar ───────────────────────────────────────
            if (!isOwnListing)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _BottomActionBar(
                  phone:      sellerPhone,
                  sellerName: sellerName,
                  isRent:     isRent,
                  vendorId:   vendorId,
                  itemData:   data,
                  onPhoneTap: sellerPhone.isNotEmpty
                      ? () => _showContactDialog(sellerPhone, sellerName)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) => const [
    '',
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];
}

// ── Share Bottom Sheet ────────────────────────────────────────────────────────
class _ShareSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ShareSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? 'Item';
    final price = data['price'];

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share Item',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.copy_rounded,
                label: 'Copy\nDetails',
                color: AppColors.primaryBlue,
                onTap: () {
                  Navigator.pop(context);
                  final text = price != null
                      ? '📦 $title\n💰 Rs. $price\n\nPosted on BazaarBuddy'
                      : '📦 $title\n\nPosted on BazaarBuddy';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Item details copied!',
                          style:
                          TextStyle(fontWeight: FontWeight.w600)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primaryBlueDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              _ShareOption(
                icon: Icons.link_rounded,
                label: 'Copy\nLink',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                    ClipboardData(
                        text:
                        'https://bazaarbuddy.app/item/${data['id'] ?? ''}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Link copied to clipboard!',
                          style:
                          TextStyle(fontWeight: FontWeight.w600)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
              _ShareOption(
                icon: Icons.message_rounded,
                label: 'Copy for\nWhatsApp',
                color: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  final text = price != null
                      ? '👋 Check out this listing on BazaarBuddy!\n\n*$title*\n💰 Rs. $price\n\nhttps://bazaarbuddy.app/item/${data['id'] ?? ''}'
                      : '👋 Check out this listing on BazaarBuddy!\n\n*$title*\n\nhttps://bazaarbuddy.app/item/${data['id'] ?? ''}';
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'WhatsApp message copied — paste in WhatsApp!',
                          style:
                          TextStyle(fontWeight: FontWeight.w600)),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _ShareOption({
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
            width: 62, height: 62,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Dialog ────────────────────────────────────────────────────────────
class _ContactDialog extends StatelessWidget {
  final String phone;
  final String sellerName;

  const _ContactDialog({required this.phone, required this.sellerName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.8),
                    AppColors.primaryBlue.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              sellerName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_outlined,
                      size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 10),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Phone number copied!',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.primaryBlueDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: BorderSide(
                          color: AppColors.primaryBlue.withOpacity(0.4)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Dial $phone in your phone dialer',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.successGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style:
                  TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Own Listing Notice ────────────────────────────────────────────────────────
class _OwnListingNotice extends StatelessWidget {
  final bool isRent;
  const _OwnListingNotice({required this.isRent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.successGreen.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppColors.successGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is your listing',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Other users can contact you to '
                      '${isRent ? 'rent' : 'buy'} this item.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat With Vendor Card ─────────────────────────────────────────────────────
class _ChatWithVendorCard extends StatelessWidget {
  final String               sellerName;
  final String               sellerAvatar;
  final String               vendorId;
  final bool                 isRent;
  final Map<String, dynamic> itemData;

  const _ChatWithVendorCard({
    required this.sellerName,
    required this.sellerAvatar,
    required this.vendorId,
    required this.isRent,
    required this.itemData,
  });

  @override
  Widget build(BuildContext context) {
    final color =
    isRent ? AppColors.accentOrange : AppColors.primaryBlue;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(
                  color: color.withOpacity(0.3), width: 2),
            ),
            child: sellerAvatar.isNotEmpty
                ? ClipOval(
              child: Image.network(sellerAvatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _AvatarFallback(name: sellerName)),
            )
                : _AvatarFallback(name: sellerName),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have questions?',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chat with $sellerName',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openChat(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_rounded,
                      size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      ),
    );
    try {
      final chatId = await ChatService().getOrCreateChat(
        otherUserId:   vendorId,
        otherUserName: sellerName,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId:        chatId,
            otherUserId:   vendorId,
            otherUserName: sellerName,
            itemContext:   itemData,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is ArgumentError ? e.message : 'Could not start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ── Image Placeholder ─────────────────────────────────────────────────────────
class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 64, color: AppColors.disabled),
      ),
    );
  }
}

// ── Listing Type Badge (on hero image) ───────────────────────────────────────
class _ListingTypeBadge extends StatelessWidget {
  final bool   isRent;
  final String durationLabel;
  const _ListingTypeBadge(
      {required this.isRent, required this.durationLabel});

  @override
  Widget build(BuildContext context) {
    final color = isRent ? AppColors.accentOrange : AppColors.primaryBlue;
    final label = isRent
        ? (durationLabel.isNotEmpty ? 'Rent $durationLabel' : 'For Rent')
        : 'For Sale';
    final icon = isRent ? Icons.key_rounded : Icons.sell_rounded;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              )),
        ],
      ),
    );
  }
}

// ── Listing Type Pill ─────────────────────────────────────────────────────────
class _ListingTypePill extends StatelessWidget {
  final bool   isRent;
  final String durationLabel;
  const _ListingTypePill(
      {required this.isRent, required this.durationLabel});

  @override
  Widget build(BuildContext context) {
    final color   = isRent ? AppColors.accentOrange : AppColors.successGreen;
    final bgColor = isRent
        ? AppColors.accentOrange.withOpacity(0.10)
        : const Color(0xFFE8F5E9);
    final icon  = isRent ? Icons.key_outlined : Icons.sell_outlined;
    final label = isRent
        ? (durationLabel.isNotEmpty ? 'Rent $durationLabel' : 'For Rent')
        : 'For Sale';
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }
}

// ── Glass Badge ───────────────────────────────────────────────────────────────
class _GlassBadge extends StatelessWidget {
  final String label;
  const _GlassBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined,
                size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Category Pill ─────────────────────────────────────────────────────────────
class _CategoryPill extends StatelessWidget {
  final String label;
  const _CategoryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryBlueLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryBlue.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline,
              size: 12, color: AppColors.primaryBlue),
          const SizedBox(width: 5),
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
                letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            )),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.border,
                  AppColors.border.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Info Grid ─────────────────────────────────────────────────────────────────
class _InfoItem {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   accentColor;
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        mainAxisSpacing:  12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (_, i) => _InfoGridTile(item: items[i]),
    );
  }
}

class _InfoGridTile extends StatelessWidget {
  final _InfoItem item;
  const _InfoGridTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.accentColor ?? AppColors.primaryBlue;
    final bg     = item.accentColor != null
        ? item.accentColor!.withOpacity(0.10)
        : AppColors.primaryBlueLight;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.accentColor != null
              ? item.accentColor!.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(item.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                      item.accentColor ?? AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seller Card ───────────────────────────────────────────────────────────────
class _SellerCard extends StatelessWidget {
  final String        name;
  final String        phone;
  final String        avatarUrl;
  final String        location;
  final VoidCallback? onContactTap;

  const _SellerCard({
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.location,
    this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top: avatar + name + badge ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Avatar with online dot
                Stack(
                  children: [
                    Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlueLight,
                        border: Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.35),
                          width: 2.5,
                        ),
                      ),
                      child: avatarUrl.isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _AvatarFallback(name: name),
                        ),
                      )
                          : _AvatarFallback(name: name),
                    ),
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                // Name + status + location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              size: 16,
                              color: AppColors.primaryBlue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.successGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Active seller',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Trusted badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                        AppColors.successGreen.withOpacity(0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 18, color: AppColors.successGreen),
                      SizedBox(height: 2),
                      Text(
                        'Trusted',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successGreen,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ─────────────────────────────────────────────────
          const Divider(
              height: 1, thickness: 1, indent: 16, endIndent: 16),

          // ── Stats row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _SellerStat(
                  icon: Icons.storefront_outlined,
                  label: 'Listings',
                  value: 'Active',
                  color: AppColors.primaryBlue,
                ),
                _StatDivider(),
                _SellerStat(
                  icon: Icons.handshake_outlined,
                  label: 'Response',
                  value: 'Fast',
                  color: AppColors.accentOrange,
                ),
                _StatDivider(),
                _SellerStat(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: '5.0 ★',
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seller Stat ───────────────────────────────────────────────────────────────
class _SellerStat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _SellerStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Divider ──────────────────────────────────────────────────────────────
class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

// ── Avatar Fallback ───────────────────────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((e) => e[0]).take(2).join();
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }
}

// ── Floating Icon Button ──────────────────────────────────────────────────────
class _FloatingIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final Color?       iconColor;

  const _FloatingIconBtn({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 19, color: iconColor ?? Colors.white),
      ),
    );
  }
}

// ── Bottom Action Bar ─────────────────────────────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  final String               phone;
  final String               sellerName;
  final bool                 isRent;
  final String               vendorId;
  final Map<String, dynamic> itemData;
  final VoidCallback?        onPhoneTap;

  const _BottomActionBar({
    required this.phone,
    required this.sellerName,
    required this.isRent,
    required this.vendorId,
    required this.itemData,
    this.onPhoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor =
    isRent ? AppColors.accentOrange : AppColors.primaryBlue;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          if (phone.isNotEmpty) ...[
            GestureDetector(
              onTap: onPhoneTap,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.contact_phone_outlined,
                    color: btnColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: vendorId.isEmpty
                    ? null
                    : () => _openChat(context),
                icon: Icon(
                  isRent
                      ? Icons.key_rounded
                      : Icons.chat_bubble_rounded,
                  size: 18,
                ),
                label: Text(
                  isRent
                      ? 'Enquire about Rental'
                      : 'Chat with $sellerName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
            color: AppColors.primaryBlue),
      ),
    );
    try {
      final chatId = await ChatService().getOrCreateChat(
        otherUserId:   vendorId,
        otherUserName: sellerName,
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId:        chatId,
            otherUserId:   vendorId,
            otherUserName: sellerName,
            itemContext:   itemData,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is ArgumentError ? e.message : 'Could not start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}