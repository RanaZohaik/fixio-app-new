import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/nav_controller.dart'; // ← updated import

class FixioBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FixioBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glassmorphic background
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 85,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.85),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    offset: const Offset(0, -3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(index: 0, icon: Icons.home_outlined, label: "Home"),
                  _navItem(index: 1, icon: Icons.grid_view_rounded, label: "Browse"),
                  const SizedBox(width: 65),
                  _navItem(index: 3, icon: Icons.chat_bubble_outline, label: "Chat"),
                  _navItem(index: 4, icon: Icons.person_outline, label: "Profile"),
                ],
              ),
            ),
          ),
        ),

        // Floating CTA — verification-gated
        Positioned(
          top: -25,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => NavController.handleUploadTap(context), // ← updated
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 55,
                width: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.9),
                      AppColors.accentOrange.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.accentOrange.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_outlined, size: 26, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool active = index == currentIndex;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: active
            ? BoxDecoration(
          color: AppColors.primaryBlueLight.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
        )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.22 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                size: 26,
                color: active ? AppColors.primaryBlueDark : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: active ? 13 : 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primaryBlueDark : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}