import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ----------------------------------------------------------------
  // Upload profile image to Firebase Storage, returns download URL
  // ----------------------------------------------------------------
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    try {
      final ref = _storage.ref().child('profile_images/$uid.jpg');
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // ----------------------------------------------------------------
  // Finalize Account: Sets Password + Uploads Image + Creates Firestore Profile
  // ----------------------------------------------------------------
  Future<String?> finalizeAccount({
    required String password,
    required String name,
    required String phone,
    required String city,
    required DateTime dob,
    File? profileImageFile, // Pass the actual File object
    String? profileImageUrl, // Or pass a pre-uploaded URL
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "No active session. Please try again.";

      // 1. Update password
      await user.updatePassword(password);

      // 2. Upload profile image if provided
      String? imageUrl = profileImageUrl;
      if (profileImageFile != null) {
        imageUrl = await uploadProfileImage(profileImageFile, user.uid);
      }

      // 3. Build and save user model
      final model = UserModel(
        uid: user.uid,
        name: name,
        email: user.email!,
        phone: phone,
        city: city,
        dob: Timestamp.fromDate(dob),
        createdAt: Timestamp.now(),
        profileImage: imageUrl,
      );

      await _firestore.collection('users').doc(user.uid).set(model.toMap());

      // 4. Update Firebase Auth display name & photo
      await user.updateDisplayName(name);
      if (imageUrl != null) await user.updatePhotoURL(imageUrl);

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ----------------------------------------------------------------
  // Update Profile (for EditProfileScreen)
  // ----------------------------------------------------------------
  Future<String?> updateProfile({
    required String name,
    required String phone,
    required String city,
    File? profileImageFile,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "No active session.";

      String? imageUrl;
      if (profileImageFile != null) {
        imageUrl = await uploadProfileImage(profileImageFile, user.uid);
      }

      final Map<String, dynamic> updates = {
        'name': name,
        'phone': phone,
        'city': city,
        'updatedAt': Timestamp.now(),
      };
      if (imageUrl != null) updates['profileImage'] = imageUrl;

      await _firestore.collection('users').doc(user.uid).update(updates);

      await user.updateDisplayName(name);
      if (imageUrl != null) await user.updatePhotoURL(imageUrl);

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ----------------------------------------------------------------
  // Login with Email & Password
  // ----------------------------------------------------------------
  Future<String?> login(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!userCred.user!.emailVerified) {
        return "Please verify your email first.";
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ----------------------------------------------------------------
  // Delete Account (requires recent login)
  // ----------------------------------------------------------------
  Future<String?> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "No active session.";

      // Re-authenticate before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete Firestore data
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete profile image from Storage
      try {
        await _storage.ref().child('profile_images/${user.uid}.jpg').delete();
      } catch (_) {} // Ignore if no image

      // Delete auth account
      await user.delete();

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ----------------------------------------------------------------
  // Disable Account (sets disabled flag in Firestore; full disable
  // requires a Cloud Function with Admin SDK)
  // ----------------------------------------------------------------
  Future<String?> disableAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "No active session.";

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Mark account as disabled in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'isDisabled': true,
        'disabledAt': Timestamp.now(),
      });

      // Sign out the user
      await _auth.signOut();

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ----------------------------------------------------------------
  // Fetch user favorites from Firestore
  // ----------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> favoritesStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> logout() async => _auth.signOut();

  // ----------------------------------------------------------------
  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'requires-recent-login':
        return 'Session expired. Please log out and log back in.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication error occurred.';
    }
  }
}