import 'package:cloud_firestore/cloud_firestore.dart';

enum CNICStatus { pending, verified }
enum LivenessStatus { notCompleted, completed }
enum UserRole { buyer, vendor }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String city;
  final Timestamp dob;
  final Timestamp createdAt;
  final String? profileImage;         // Optional profile image URL
  final CNICStatus cnicStatus;        // CNIC verification status
  final LivenessStatus livenessStatus;// Liveness verification status
  final UserRole role;                 // buyer/vendor
  final int listingsCount;             // Vendor: number of active listings
  final int completedDeals;            // Vendor: completed deals
  final double rating;                 // Vendor: average rating (0-5)

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.dob,
    required this.createdAt,
    this.profileImage,
    this.cnicStatus = CNICStatus.pending,
    this.livenessStatus = LivenessStatus.notCompleted,
    this.role = UserRole.buyer,
    this.listingsCount = 0,
    this.completedDeals = 0,
    this.rating = 0.0,
  });

  /// Create UserModel from Firestore document
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    CNICStatus parseCNIC(String? val) {
      switch (val) {
        case 'verified':
          return CNICStatus.verified;
        default:
          return CNICStatus.pending;
      }
    }

    LivenessStatus parseLiveness(String? val) {
      switch (val) {
        case 'completed':
          return LivenessStatus.completed;
        default:
          return LivenessStatus.notCompleted;
      }
    }

    UserRole parseRole(String? val) {
      switch (val) {
        case 'vendor':
          return UserRole.vendor;
        default:
          return UserRole.buyer;
      }
    }

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      city: data['city'] ?? '',
      dob: data['dob'] ?? Timestamp.now(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      profileImage: data['profileImage'],
      cnicStatus: parseCNIC(data['cnicStatus']),
      livenessStatus: parseLiveness(data['livenessStatus']),
      role: parseRole(data['role']),
      listingsCount: data['listingsCount'] ?? 0,
      completedDeals: data['completedDeals'] ?? 0,
      rating: (data['rating'] ?? 0).toDouble(),
    );
  }

  /// Convert UserModel to Firestore Map
  Map<String, dynamic> toMap() {
    String cnicStr = cnicStatus == CNICStatus.verified ? 'verified' : 'pending';
    String liveStr = livenessStatus == LivenessStatus.completed ? 'completed' : 'notCompleted';
    String roleStr = role == UserRole.vendor ? 'vendor' : 'buyer';

    return {
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'dob': dob,
      'createdAt': createdAt,
      'profileImage': profileImage,
      'cnicStatus': cnicStr,
      'livenessStatus': liveStr,
      'role': roleStr,
      'listingsCount': listingsCount,
      'completedDeals': completedDeals,
      'rating': rating,
    };
  }

  /// Helper getters to convert Timestamps to DateTime
  DateTime get dobDateTime => dob.toDate();
  DateTime get createdAtDateTime => createdAt.toDate();

  /// Copy with method for easy updates
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    Timestamp? dob,
    String? profileImage,
    CNICStatus? cnicStatus,
    LivenessStatus? livenessStatus,
    UserRole? role,
    int? listingsCount,
    int? completedDeals,
    double? rating,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      dob: dob ?? this.dob,
      createdAt: createdAt,
      profileImage: profileImage ?? this.profileImage,
      cnicStatus: cnicStatus ?? this.cnicStatus,
      livenessStatus: livenessStatus ?? this.livenessStatus,
      role: role ?? this.role,
      listingsCount: listingsCount ?? this.listingsCount,
      completedDeals: completedDeals ?? this.completedDeals,
      rating: rating ?? this.rating,
    );
  }

  /// Convenience methods for displaying verification badges
  bool get isCNICVerified => cnicStatus == CNICStatus.verified;
  bool get isLivenessCompleted => livenessStatus == LivenessStatus.completed;
  bool get isVendor => role == UserRole.vendor;
}
