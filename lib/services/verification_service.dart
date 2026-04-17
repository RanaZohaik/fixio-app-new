// lib/services/verification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VerificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _storage = FirebaseStorage.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK IF USER IS VERIFIED
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> isUserVerified() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists) return false;

    return doc.data()?["isVerified"] == true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET FULL VERIFICATION STATUS (for UI display)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getVerificationStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {"step": "not_started"};

    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists) return {"step": "not_started"};

    return doc.data() ?? {"step": "not_started"};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD CNIC IMAGE
  // Cloud Function triggers automatically after upload
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> uploadCnicImage(
      File file, {
        required String side,
        Function(double)? onProgress,
      }) async {
    final uid = _auth.currentUser!.uid;
    final ref = _storage.ref().child("users/$uid/cnic_$side.jpg");

    // Upload with progress tracking
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg"),
    );

    // Track upload progress
    uploadTask.snapshotEvents.listen((snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress?.call(progress);
    });

    await uploadTask;
    final url = await ref.getDownloadURL();

    // Save URL to Firestore (Cloud Function will update the rest)
    await _firestore.collection("users").doc(uid).set({
      side == "front" ? "cnicFrontUrl" : "cnicBackUrl": url,
      "verificationStep": "cnic_uploaded",
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD SELFIE
  // Cloud Function triggers automatically after upload
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> uploadLivenessSelfie(
      File file, {
        Function(double)? onProgress,
      }) async {
    final uid = _auth.currentUser!.uid;
    final ref = _storage.ref().child("users/$uid/selfie.jpg");

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: "image/jpeg"),
    );

    uploadTask.snapshotEvents.listen((snapshot) {
      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress?.call(progress);
    });

    await uploadTask;
    final url = await ref.getDownloadURL();

    // Mark selfie as uploaded — Cloud Function handles the rest
    await _firestore.collection("users").doc(uid).set({
      "selfieUrl": url,
      "verificationStep": "selfie_uploaded",
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM: Listen for verification result in real-time
  // Use this in LivenessCheckScreen to auto-detect when Cloud Function finishes
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<DocumentSnapshot> watchVerificationStatus() {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection("users").doc(uid).snapshots();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM: Wait for OCR completion (after CNIC upload)
  // Returns the extracted data when Cloud Function finishes OCR
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> waitForOcrResult({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uid = _auth.currentUser!.uid;
    final completer = Completer<Map<String, dynamic>>();

    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      sub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException("OCR timed out", timeout));
      }
    });

    sub = _firestore
        .collection("users")
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final step = data["verificationStep"] as String? ?? "";
      final ocrStatus = data["ocrStatus"] as String? ?? "";

      if (ocrStatus == "success" || step == "ocr_done") {
        timer.cancel();
        sub.cancel();
        if (!completer.isCompleted) completer.complete(data);
      } else if (ocrStatus == "failed") {
        timer.cancel();
        sub.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception(data["ocrError"] ?? "OCR failed"));
        }
      }
    });

    return completer.future;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM: Wait for face match result (after selfie upload)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<VerificationResult> waitForFaceMatchResult({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uid = _auth.currentUser!.uid;
    final completer = Completer<VerificationResult>();

    late StreamSubscription sub;
    final timer = Timer(timeout, () {
      sub.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException("Face match timed out", timeout));
      }
    });

    sub = _firestore
        .collection("users")
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data == null) return;

      final step = data["verificationStep"] as String? ?? "";

      switch (step) {
        case "completed":
          timer.cancel();
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(VerificationResult(
              status: VerificationStatus.verified,
              confidence: (data["faceMatchConfidence"] as num?)?.toDouble(),
              message: "Identity verified successfully!",
            ));
          }
          break;

        case "face_mismatch":
          timer.cancel();
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(VerificationResult(
              status: VerificationStatus.faceMismatch,
              confidence: (data["faceMatchConfidence"] as num?)?.toDouble(),
              message: "Face does not match your CNIC photo.",
            ));
          }
          break;

        case "liveness_failed":
          timer.cancel();
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(VerificationResult(
              status: VerificationStatus.livenessFailed,
              message: "Liveness check failed. Please retake your selfie.",
            ));
          }
          break;

        case "error":
          timer.cancel();
          sub.cancel();
          if (!completer.isCompleted) {
            completer.complete(VerificationResult(
              status: VerificationStatus.error,
              message: data["faceMatchError"] ?? "Verification error occurred.",
            ));
          }
          break;
      }
    });

    return completer.future;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Models
// ─────────────────────────────────────────────────────────────────────────────
enum VerificationStatus { verified, faceMismatch, livenessFailed, error }

class VerificationResult {
  final VerificationStatus status;
  final double? confidence;
  final String message;

  const VerificationResult({
    required this.status,
    required this.message,
    this.confidence,
  });
}