import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});
  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('vendorId', isEqualTo: uid)
          .snapshots(),
      builder: (context, itemSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('vendorId', isEqualTo: uid)
              .snapshots(),
          builder: (context, orderSnap) {

            if (!itemSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              );
            }

            final itemDocs  = itemSnap.data!.docs;
            final orderDocs = orderSnap.data?.docs ?? [];

            // ── Item stats ──────────────────────────────
            final totalListings = itemDocs.length;
            final activeListings = itemDocs.where((d) =>
            (d.data() as Map)['status'] == 'active').length;
            final forRent = itemDocs.where((d) =>
            (d.data() as Map)['listingType'] == 'rent').length;
            final forSale = totalListings - forRent;

            // ── Order stats ─────────────────────────────
            final totalOrders   = orderDocs.length;
            final rentOrders    = orderDocs.where((d) =>
            (d.data() as Map)['type'] == 'rent').length;
            final saleOrders    = orderDocs.where((d) =>
            (d.data() as Map)['type'] == 'sale').length;
            final pendingOrders = orderDocs.where((d) =>
            (d.data() as Map)['status'] == 'pending').length;
            final completedOrders = orderDocs.where((d) =>
            (d.data() as Map)['status'] == 'completed').length;

            // ── Monthly data for bar chart ───────────────
            final Map<String, int> monthlyListings = {};
            for (final doc in itemDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts   = data['createdAt'];
              if (ts != null) {
                try {
                  final dt  = (ts as dynamic).toDate() as DateTime;
                  final key = _monthKey(dt);
                  monthlyListings[key] = (monthlyListings[key] ?? 0) + 1;
                } catch (_) {}
              }
            }

            final Map<String, int> monthlyOrders = {};
            for (final doc in orderDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts   = data['createdAt'];
              if (ts != null) {
                try {
                  final dt  = (ts as dynamic).toDate() as DateTime;
                  final key = _monthKey(dt);
                  monthlyOrders[key] = (monthlyOrders[key] ?? 0) + 1;
                } catch (_) {}
              }
            }

            final months     = _last6Months();
            final listingBars = months.map((m) => monthlyListings[m] ?? 0).toList();
            final orderBars   = months.map((m) => monthlyOrders[m]  ?? 0).toList();
            final maxBar      = [...listingBars, ...orderBars, 1]
                .reduce((a, b) => a > b ? a : b)
                .toDouble();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ────────────────────────────
                  _DashHeader(
                    title:    "Analytics",
                    subtitle: "Your store at a glance",
                  ),
                  const SizedBox(height: 20),

                  // ── Top KPI row ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label:   "Total Listings",
                          value:   "$totalListings",
                          icon:    Icons.inventory_2_outlined,
                          color:   AppColors.primaryBlue,
                          sub:     "$activeListings active",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          label:   "Total Orders",
                          value:   "$totalOrders",
                          icon:    Icons.shopping_bag_outlined,
                          color:   const Color(0xFF22C55E),
                          sub:     "$completedOrders done",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label:   "For Sale",
                          value:   "$forSale",
                          icon:    Icons.storefront_rounded,
                          color:   AppColors.primaryBlue,
                          sub:     "$saleOrders orders",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          label:   "For Rent",
                          value:   "$forRent",
                          icon:    Icons.key_rounded,
                          color:   AppColors.accentOrange,
                          sub:     "$rentOrders orders",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Monthly Activity Chart ─────────────
                  _SectionTitle(title: "Monthly Activity", icon: Icons.bar_chart_rounded),
                  const SizedBox(height: 14),
                  _BarChartCard(
                    months:      months.map(_shortMonth).toList(),
                    listingBars: listingBars,
                    orderBars:   orderBars,
                    maxVal:      maxBar,
                  ),

                  const SizedBox(height: 24),

                  // ── Distribution ───────────────────────
                  _SectionTitle(title: "Listing Distribution", icon: Icons.pie_chart_outline_rounded),
                  const SizedBox(height: 14),
                  _DistributionCard(
                    forSale:  forSale,
                    forRent:  forRent,
                    total:    totalListings,
                    active:   activeListings,
                    inactive: totalListings - activeListings,
                  ),

                  const SizedBox(height: 24),

                  // ── Recent Orders ──────────────────────
                  if (orderDocs.isNotEmpty) ...[
                    _SectionTitle(
                        title: "Recent Orders",
                        icon:  Icons.receipt_long_outlined),
                    const SizedBox(height: 14),
                    _RecentOrdersList(orderDocs: orderDocs.take(5).toList()),
                  ],

                  // ── Recent Listings ────────────────────
                  if (itemDocs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle(
                        title: "Recent Listings",
                        icon:  Icons.sell_outlined),
                    const SizedBox(height: 14),
                    _RecentListingsList(itemDocs: itemDocs.take(5).toList()),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _last6Months() {
    final now  = DateTime.now();
    final list = <String>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      list.add(_monthKey(d));
    }
    return list;
  }

  String _monthKey(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}";
  String _shortMonth(String key) {
    final parts = key.split('-');
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[int.parse(parts[1])];
  }
}

// ── Dash Header ───────────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DashHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E), letterSpacing: -0.5,
            )),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(
              fontSize: 13, color: const Color(0xFF6B7280).withOpacity(0.85),
            )),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Container(width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFF22C55E), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text("Live", style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            )),
          ]),
        ),
      ],
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final String   sub;

  const _KpiCard({
    required this.label, required this.value,
    required this.icon,  required this.color, required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(sub, style: const TextStyle(
            fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600,
          )),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -1, height: 1.0,
        )),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
          fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600,
        )),
      ]),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String   title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primaryBlue),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A2E), letterSpacing: -0.3,
      )),
    ]);
  }
}

// ── Bar Chart Card ────────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final List<String> months;
  final List<int>    listingBars;
  final List<int>    orderBars;
  final double       maxVal;

  const _BarChartCard({
    required this.months,
    required this.listingBars,
    required this.orderBars,
    required this.maxVal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Legend
        Row(children: [
          _LegendDot(color: AppColors.primaryBlue,  label: "Listings"),
          const SizedBox(width: 16),
          _LegendDot(color: const Color(0xFF22C55E), label: "Orders"),
        ]),
        const SizedBox(height: 20),

        // Bars
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(months.length, (i) {
              final lRatio = maxVal > 0 ? listingBars[i] / maxVal : 0.0;
              final oRatio = maxVal > 0 ? orderBars[i]  / maxVal : 0.0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(
                          ratio: lRatio,
                          color: AppColors.primaryBlue,
                          maxH:  120,
                        ),
                        const SizedBox(width: 3),
                        _Bar(
                          ratio: oRatio,
                          color: const Color(0xFF22C55E),
                          maxH:  120,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(months[i], style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final double ratio;
  final Color  color;
  final double maxH;
  const _Bar({required this.ratio, required this.color, required this.maxH});

  @override
  Widget build(BuildContext context) {
    final h = (ratio * maxH).clamp(4.0, maxH);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      width: 10,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280),
      )),
    ]);
  }
}

// ── Distribution Card ─────────────────────────────────────────────────────────
class _DistributionCard extends StatelessWidget {
  final int forSale, forRent, total, active, inactive;
  const _DistributionCard({
    required this.forSale, required this.forRent,
    required this.total, required this.active, required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [

        // Sale vs Rent bar
        _DistRow(
          label: "Sale vs Rent",
          val1: forSale, val2: forRent, total: total,
          color1: AppColors.primaryBlue,
          color2: AppColors.accentOrange,
          label1: "Sale", label2: "Rent",
        ),
        const SizedBox(height: 16),

        // Active vs Inactive bar
        _DistRow(
          label: "Active vs Inactive",
          val1: active, val2: inactive, total: total,
          color1: const Color(0xFF22C55E),
          color2: const Color(0xFFE2E8F0),
          label1: "Active", label2: "Inactive",
        ),
      ]),
    );
  }
}

class _DistRow extends StatelessWidget {
  final String label;
  final int    val1, val2, total;
  final Color  color1, color2;
  final String label1, label2;

  const _DistRow({
    required this.label, required this.val1, required this.val2,
    required this.total, required this.color1, required this.color2,
    required this.label1, required this.label2,
  });

  @override
  Widget build(BuildContext context) {
    final r1 = total == 0 ? 0.0 : val1 / total;
    final r2 = total == 0 ? 0.0 : val2 / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280),
        )),
        Row(children: [
          _LegendDot(color: color1,
              label: "$label1 ($val1)"),
          const SizedBox(width: 12),
          _LegendDot(color: color2,
              label: "$label2 ($val2)"),
        ]),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 10,
          child: Row(children: [
            Flexible(flex: (r1 * 100).round().clamp(0, 100), child: Container(color: color1)),
            Flexible(flex: (r2 * 100).round().clamp(0, 100), child: Container(color: color2.withOpacity(0.5))),
          ]),
        ),
      ),
    ]);
  }
}

// ── Recent Orders List ────────────────────────────────────────────────────────
class _RecentOrdersList extends StatelessWidget {
  final List<QueryDocumentSnapshot> orderDocs;
  const _RecentOrdersList({required this.orderDocs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: orderDocs.asMap().entries.map((entry) {
          final i    = entry.key;
          final doc  = entry.value;
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          final type   = data['type']   as String? ?? 'sale';
          final title  = data['itemTitle'] as String? ?? 'Item';
          final price  = data['price'];

          final isLast        = i == orderDocs.length - 1;
          final statusColor   = status == 'completed'
              ? const Color(0xFF22C55E)
              : status == 'pending'
              ? AppColors.accentOrange
              : const Color(0xFF94A3B8);
          final statusBg      = status == 'completed'
              ? const Color(0xFFEFFEF4)
              : status == 'pending'
              ? AppColors.accentOrange.withOpacity(0.1)
              : const Color(0xFFF1F5F9);
          final typeColor     = type == 'rent'
              ? AppColors.accentOrange : AppColors.primaryBlue;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    type == 'rent' ? Icons.key_rounded : Icons.shopping_bag_outlined,
                    color: typeColor, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        )),
                    if (price != null)
                      Text("Rs. $price", style: TextStyle(
                        fontSize: 12, color: const Color(0xFFFF6B35).withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      )),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.capitalize(), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: statusColor,
                  )),
                ),
              ]),
            ),
            if (!isLast)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: Colors.grey.withOpacity(0.1)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Recent Listings List ──────────────────────────────────────────────────────
class _RecentListingsList extends StatelessWidget {
  final List<QueryDocumentSnapshot> itemDocs;
  const _RecentListingsList({required this.itemDocs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: itemDocs.asMap().entries.map((entry) {
          final i      = entry.key;
          final doc    = entry.value;
          final data   = doc.data() as Map<String, dynamic>;
          final title  = data['title']       as String? ?? 'Untitled';
          final price  = data['price'];
          final status = data['status']      as String? ?? 'active';
          final type   = data['listingType'] as String? ?? 'sell';
          final image  = data['image']       as String? ?? '';

          final isLast      = i == itemDocs.length - 1;
          final isActive    = status == 'active';
          final isRent      = type == 'rent';
          final typeColor   = isRent ? AppColors.accentOrange : AppColors.primaryBlue;
          final statusColor = isActive ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
          final statusBg    = isActive ? const Color(0xFFEFFEF4) : const Color(0xFFF1F5F9);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 46, height: 46,
                    child: image.isNotEmpty
                        ? Image.network(image, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F6FB),
                          child: const Icon(Icons.image_outlined,
                              size: 20, color: Color(0xFF94A3B8)),
                        ))
                        : Container(color: const Color(0xFFF3F6FB),
                        child: const Icon(Icons.image_outlined,
                            size: 20, color: Color(0xFF94A3B8))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        )),
                    Row(children: [
                      if (price != null)
                        Text("Rs. $price  ", style: TextStyle(
                          fontSize: 12, color: const Color(0xFFFF6B35).withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                        )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isRent ? "Rent" : "Sale",
                            style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: typeColor,
                            )),
                      ),
                    ]),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.capitalize(), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: statusColor,
                  )),
                ),
              ]),
            ),
            if (!isLast)
              Divider(height: 1, indent: 16, endIndent: 16,
                  color: Colors.grey.withOpacity(0.1)),
          ]);
        }).toList(),
      ),
    );
  }
}

extension StringCapExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}