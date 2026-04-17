import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class FixioAppBar extends StatefulWidget implements PreferredSizeWidget {
  const FixioAppBar({super.key});

  // Match picture's compact height
  @override
  Size get preferredSize => const Size.fromHeight(200);

  @override
  State<FixioAppBar> createState() => _FixioAppBarState();
}

class _FixioAppBarState extends State<FixioAppBar> {
  String userName = "User";
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            userName = (doc.data()?['name'] as String?) ?? "User";
            photoUrl = (doc.data()?['photoUrl'] as String?);
          });
        }
      }
    } catch (e) {
      // keep defaults on error
      debugPrint("Error fetching user profile: $e");
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primaryBlue,
      elevation: 6,
      shadowColor: AppColors.shadow.withOpacity(0.4),
      automaticallyImplyLeading: false,
      // remove default titleSpacing so we control layout precisely
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 12.0, right: 12.0),
        child: Row(
          children: [
            // Left avatar (small circular)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // subtle outer shadow similar to image
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
              ),
            ),

            const SizedBox(width: 32),

            // Texts (Hi name \n greeting)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // row with Hi and name like the image ("Hi David")
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Hi ",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          userName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Greeting under the name ("Good Morning")
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Right: notification bell (matches picture)
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.notifications);
              },
              tooltip: "Notifications",
            ),
          ],
        ),
      ),
    );
  }
}
