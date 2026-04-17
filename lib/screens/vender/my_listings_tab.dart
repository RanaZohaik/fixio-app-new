import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import 'edit_item_screen.dart';

class MyListingsTab extends StatelessWidget {
  const MyListingsTab({super.key});

  Future<void> _deleteItem(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                "Delete Listing?",
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "This action cannot be undone.\nThe listing will be permanently removed.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Delete",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('items').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('vendorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {

        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        // Empty
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      size: 38,
                      color: AppColors.primaryBlue.withOpacity(0.55)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "No listings yet",
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Tap + to add your first listing!",
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: [

            // ── Summary header bar ─────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "My Listings",
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A2E), letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      "${docs.length} listing${docs.length == 1 ? '' : 's'} total",
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )),

                // Active count chip
                _SummaryChip(
                  label: "${docs.where((d) => (d.data() as Map)['status'] == 'active').length} Active",
                  color: const Color(0xFF22C55E),
                  bg:    const Color(0xFFEFFEF4),
                ),
                const SizedBox(width: 8),

                // Rent count chip
                _SummaryChip(
                  label: "${docs.where((d) => (d.data() as Map)['listingType'] == 'rent').length} Rent",
                  color: AppColors.accentOrange,
                  bg:    AppColors.accentOrange.withOpacity(0.1),
                ),
              ]),
            ),

            Container(height: 1, color: const Color(0xFFE2E8F0)),

            // ── List ───────────────────────────────────
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _ListingCard(
                    data:     data,
                    onEdit:   () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditItemScreen(docId: doc.id, data: data),
                        ),
                      );
                    },
                    onDelete: () {
                      HapticFeedback.lightImpact();
                      _deleteItem(context, doc.id);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Summary Chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final Color  color, bg;
  const _SummaryChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: color,
      )),
    );
  }
}

// ── Listing Card ──────────────────────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback         onEdit;
  final VoidCallback         onDelete;

  const _ListingCard({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl    = data['image']        as String? ?? '';
    final title       = data['title']        as String? ?? 'Untitled';
    final price       = data['price'];
    final status      = data['status']       as String? ?? 'active';
    final listingType = data['listingType']  as String? ?? 'sell';
    final condition   = data['condition']    as String? ?? '';
    final location    = data['location']     as String? ?? '';
    final description = data['description'] as String? ?? '';

    final bool   isRent      = listingType == 'rent';
    final bool   isActive    = status == 'active';
    final Color  typeColor   = isRent ? AppColors.accentOrange : AppColors.primaryBlue;
    final String typeLabel   = isRent ? 'FOR RENT' : 'FOR SALE';
    final Color  statusColor = isActive
        ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
    final Color  statusBg    = isActive
        ? const Color(0xFFEFFEF4) : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 4, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top row: image + details ───────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Image stack
                Stack(
                  children: [
                    SizedBox(
                      width: 112, height: 128,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl, fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return _ImgFallback(loading: true);
                        },
                        errorBuilder: (_, __, ___) =>
                            _ImgFallback(loading: false),
                      )
                          : _ImgFallback(loading: false),
                    ),

                    // Type badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(7),
                          boxShadow: [
                            BoxShadow(
                              color: typeColor.withOpacity(0.4),
                              blurRadius: 6, offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(typeLabel, style: const TextStyle(
                          fontSize: 7.5, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 0.6,
                        )),
                      ),
                    ),

                    // Condition badge on image bottom
                    if (condition.isNotEmpty)
                      Positioned(
                        bottom: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(condition, style: const TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                        ),
                      ),
                  ],
                ),

                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 13, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Title + status row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1A2E),
                                    height: 1.3, letterSpacing: -0.3,
                                  )),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5, height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    status[0].toUpperCase() +
                                        status.substring(1),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        // Price
                        if (price != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Rs.", style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: const Color(0xFFFF6B35).withOpacity(0.8),
                              )),
                              const SizedBox(width: 2),
                              Text("$price", style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: Color(0xFFFF6B35),
                                letterSpacing: -0.5, height: 1.0,
                              )),
                              if (isRent) ...[
                                const SizedBox(width: 2),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 1),
                                  child: Text("/day", style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFF6B35)
                                        .withOpacity(0.6),
                                  )),
                                ),
                              ],
                            ],
                          ),

                        const SizedBox(height: 6),

                        // Description preview
                        if (description.isNotEmpty)
                          Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF9CA3AF),
                                height: 1.4,
                              )),

                        // Location
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 11, color: Color(0xFF9CA3AF)),
                            const SizedBox(width: 3),
                            Expanded(child: Text(location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5, color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w500,
                                ))),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Divider ────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.grey.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),

            // ── Action row ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [

                // Edit button
                Expanded(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 14, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text("Edit Listing", style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 5),
                      const Text("Delete", style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.red,
                      )),
                    ]),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image Fallback ────────────────────────────────────────────────────────────
class _ImgFallback extends StatelessWidget {
  final bool loading;
  const _ImgFallback({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F6FB),
      child: Center(
        child: loading
            ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primaryBlue,
            ))
            : Icon(Icons.image_outlined,
            size: 26, color: Colors.grey.withOpacity(0.4)),
      ),
    );
  }
}