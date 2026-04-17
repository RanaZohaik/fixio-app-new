// lib/utils/nav_controller.dart

import 'package:flutter/material.dart';
import 'package:fixio/screens/vender/vendor_dashboard_screen.dart';
import '../services/verification_service.dart';
import '../screens/verification/verification_pending_screen.dart'; // ← your CNIC screen

class NavController {
  // ---------------------------------------------------------------------------
  // HANDLE UPLOAD CTA BUTTON TAP
  // ---------------------------------------------------------------------------
  static Future<void> handleUploadTap(BuildContext context) async {
    // Show loading while checking
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool isVerified = false;

    try {
      isVerified = await VerificationService.isUserVerified();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification check failed: $e")),
      );
      return;
    }

    Navigator.pop(context); // Remove loading

    if (isVerified) {
      // ✅ VERIFIED → Go to Vendor Dashboard
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VendorDashboardScreen()),
      );
    } else {
      // ❌ NOT VERIFIED → Show beautiful CNIC popup
      _showCnicVerificationDialog(context);
    }
  }

  // ---------------------------------------------------------------------------
  // BEAUTIFUL CNIC VERIFICATION POPUP
  // ---------------------------------------------------------------------------
  static void _showCnicVerificationDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (_, __, ___) => const _CnicDialog(),
    );
  }
}

// ---------------------------------------------------------------------------
// CNIC DIALOG WIDGET
// ---------------------------------------------------------------------------
class _CnicDialog extends StatelessWidget {
  const _CnicDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Gradient header banner ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1565C0),
                        const Color(0xFFFF6D00).withOpacity(0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Shield / ID icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.45),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Verification Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    children: [
                      const Text(
                        'To become a vendor on Fixio, you need to verify your identity with your CNIC first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF555555),
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info chip row
                      Row(
                        children: [
                          _infoChip(Icons.lock_outline, 'Secure'),
                          const SizedBox(width: 10),
                          _infoChip(Icons.timer_outlined, 'Takes ~2 min'),
                          const SizedBox(width: 10),
                          _infoChip(Icons.verified_outlined, 'One-time only'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Primary CTA
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // close dialog
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VerificationPendingScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                            label: const Text(
                              'Verify CNIC Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Dismiss
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Maybe Later',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD0DCFF), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1565C0)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444466),
              ),
            ),
          ],
        ),
      ),
    );
  }
}