import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<CategoryModel>> getCategories() {
    return _db
        .collection('categories')
        .where('isActive', isEqualTo: true)
    // ✅ FIX: Removed .orderBy('priority') — combining .where() on one
    // field with .orderBy() on a different field requires a composite
    // Firestore index. We sort client-side instead.
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort by priority client-side (safe, no index needed)
      list.sort((a, b) => (a.priority ?? 0).compareTo(b.priority ?? 0));
      return list;
    });
  }
}