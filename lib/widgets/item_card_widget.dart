import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../screens/home/item_detail_screen.dart';

class ItemCardWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const ItemCardWidget({
    super.key,
    required this.data,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // All sizes are proportional to card width
        final imageH   = (w * 0.70).clamp(90.0, 175.0);
        final titleSz  = (w * 0.085).clamp(11.0, 14.0);
        final priceSz  = (w * 0.115).clamp(13.5, 18.0);
        final badgeSz  = (w * 0.055).clamp(6.5, 9.5);
        final padH     = (w * 0.04).clamp(8.0, 14.0);
        final padV     = (w * 0.035).clamp(7.0, 12.0);

        final imageUrl     = data['image']        as String? ?? '';
        final title        = data['title']        as String? ?? 'Untitled';
        final price        = data['price'];
        final categoryName = data['categoryName'] as String? ?? '';
        final condition    = data['condition']    as String? ?? '';
        final location     = data['location']     as String? ?? '';
        final sellerName   = data['sellerName']   as String? ?? '';
        final listingType  = data['listingType']  as String? ?? 'sell';
        final rentDuration = data['rentDuration'] as String? ?? '';

        final bool     isRent        = listingType == 'rent';
        final String   durationLabel =
        rentDuration.isNotEmpty ? '/$rentDuration' : '';
        final Color    badgeColor =
        isRent ? const Color(0xFFFF6B35) : AppColors.primaryBlue;
        final String   badgeLabel = isRent ? 'FOR RENT' : 'FOR SALE';
        final IconData badgeIcon  =
        isRent ? Icons.key_rounded : Icons.storefront_rounded;

        // Enrich data with docId for detail screen
        final enrichedData = {'id': docId, ...data};

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemDetailScreen(
                  data:  enrichedData,
                  docId: docId,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.07),
                  blurRadius: 18,
                  offset:     const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Image ──────────────────────────────────────────
                  Stack(
                    children: [
                      SizedBox(
                        height: imageH,
                        width:  double.infinity,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const _ImageFallback(isLoading: true);
                          },
                          errorBuilder: (_, __, ___) =>
                          const _ImageFallback(isLoading: false),
                        )
                            : const _ImageFallback(isLoading: false),
                      ),

                      // Bottom scrim
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: imageH * 0.42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Listing badge — top left
                      Positioned(
                        top: 7, left: 7,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: (badgeSz * 0.85).clamp(5.0, 9.0),
                              vertical:   (badgeSz * 0.45).clamp(2.5, 5.0)),
                          decoration: BoxDecoration(
                            color:        badgeColor,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color:      badgeColor.withOpacity(0.4),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon,
                                  size: badgeSz, color: Colors.white),
                              SizedBox(
                                  width: (badgeSz * 0.4).clamp(2.0, 4.0)),
                              Text(
                                badgeLabel,
                                style: TextStyle(
                                  fontSize:     badgeSz,
                                  fontWeight:   FontWeight.w900,
                                  color:        Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Condition chip — top right
                      if (condition.isNotEmpty)
                        Positioned(
                          top: 7, right: 7,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: (badgeSz * 0.85).clamp(5.0, 9.0),
                                vertical:   (badgeSz * 0.45).clamp(2.5, 5.0)),
                            decoration: BoxDecoration(
                              color:        Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.35)),
                            ),
                            child: Text(
                              condition.toUpperCase(),
                              style: TextStyle(
                                fontSize:     badgeSz,
                                fontWeight:   FontWeight.w800,
                                color:        Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                      // Location — bottom of image
                      if (location.isNotEmpty)
                        Positioned(
                          bottom: 6, left: 8, right: 8,
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: (badgeSz * 1.1).clamp(8.0, 12.0),
                                  color: Colors.white),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize:   (badgeSz * 1.0).clamp(8.0, 11.0),
                                    color:      Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // ── Body ────────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category pill
                        if (categoryName.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: (padH * 0.55).clamp(4.0, 8.0),
                                vertical:   2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              categoryName.toUpperCase(),
                              style: TextStyle(
                                fontSize:     (badgeSz - 0.5).clamp(6.0, 9.0),
                                fontWeight:   FontWeight.w800,
                                color: AppColors.primaryBlue.withOpacity(0.85),
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          SizedBox(height: (padV * 0.45).clamp(3.0, 6.0)),
                        ],

                        // Title
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize:     titleSz,
                            fontWeight:   FontWeight.w800,
                            color:        const Color(0xFF1A1A2E),
                            height:       1.25,
                            letterSpacing: -0.2,
                          ),
                        ),

                        SizedBox(height: (padV * 0.55).clamp(4.0, 8.0)),

                        // Price
                        if (price != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs.',
                                style: TextStyle(
                                  fontSize:   priceSz * 0.58,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF6B35)
                                      .withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$price',
                                style: TextStyle(
                                  fontSize:     priceSz,
                                  fontWeight:   FontWeight.w900,
                                  color:        const Color(0xFFFF6B35),
                                  letterSpacing: -0.4,
                                  height:       1.0,
                                ),
                              ),
                              if (isRent && durationLabel.isNotEmpty) ...[
                                const SizedBox(width: 2),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 1),
                                  child: Text(
                                    durationLabel,
                                    style: TextStyle(
                                      fontSize:   priceSz * 0.52,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFF6B35)
                                          .withOpacity(0.65),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: (padV * 0.55).clamp(4.0, 8.0)),
                        ],

                        // Divider
                        Container(
                          height: 0.5,
                          color: Colors.black.withOpacity(0.07),
                        ),

                        SizedBox(height: (padV * 0.55).clamp(4.0, 8.0)),

                        // Seller row
                        Row(
                          children: [
                            Container(
                              width: (titleSz * 1.6).clamp(18.0, 26.0),
                              height: (titleSz * 1.6).clamp(18.0, 26.0),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryBlue,
                              ),
                              child: Center(
                                child: Text(
                                  sellerName.trim().isNotEmpty
                                      ? sellerName.trim()[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize:   (titleSz * 0.6).clamp(7.0, 10.0),
                                    fontWeight: FontWeight.w900,
                                    color:      Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: (padH * 0.45).clamp(4.0, 7.0)),
                            Expanded(
                              child: Text(
                                sellerName.isNotEmpty
                                    ? sellerName
                                    : 'Unknown',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize:   (titleSz * 0.77).clamp(8.5, 11.5),
                                  fontWeight: FontWeight.w600,
                                  color:      const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Container(
                              width: (titleSz * 1.3).clamp(14.0, 20.0),
                              height: (titleSz * 1.3).clamp(14.0, 20.0),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  size:  (titleSz * 0.72).clamp(8.0, 12.0),
                                  color: const Color(0xFF43A047),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Image Fallback ────────────────────────────────────────────────────────────
class _ImageFallback extends StatelessWidget {
  final bool isLoading;
  const _ImageFallback({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F6FB),
      child: Center(
        child: isLoading
            ? const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primaryBlue),
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined,
                size: 30, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(
                fontSize:   9,
                color:      Colors.grey.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}