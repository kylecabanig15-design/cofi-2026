import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cofi/models/review_model.dart';
import 'package:cofi/models/shop_model.dart';

/// Read/write access for shops and their subcollections (reviews, visits).
class ShopRepository {
  ShopRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _exploreLimit = 300;
  static const int _recentReviewsLimit = 10;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  DocumentReference<Map<String, dynamic>> shopRef(String shopId) =>
      _shops.doc(shopId);

  /// Explore feed variants. [orderBy] mirrors the existing chip behaviour:
  /// postedAt (newest) or ratings (top rated).
  Stream<List<Shop>> watchVerifiedShops({
    String orderBy = 'postedAt',
    int limit = _exploreLimit,
  }) {
    return _shops
        .where('isVerified', isEqualTo: true)
        .orderBy(orderBy, descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Shop.fromFirestore(d.data(), d.id)).toList());
  }

  Future<Shop?> getShop(String shopId) async {
    final doc = await shopRef(shopId).get();
    if (!doc.exists) return null;
    return Shop.fromFirestore(doc.data()!, doc.id);
  }

  Stream<Shop?> watchShop(String shopId) {
    return shopRef(shopId).snapshots().map(
        (d) => d.exists ? Shop.fromFirestore(d.data()!, d.id) : null);
  }

  // ----- Reviews -----

  Stream<List<Review>> watchRecentReviews(String shopId, {int? limit}) {
    return shopRef(shopId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(limit ?? _recentReviewsLimit)
        .snapshots()
        .map(_parseReviews);
  }

  Future<List<Review>> fetchReviews(String shopId,
      {int pageSize = 20, Review? startAfter}) async {
    Query<Map<String, dynamic>> query = shopRef(shopId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      final startDoc = await shopRef(shopId)
          .collection('reviews')
          .doc(startAfter.id)
          .get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }
    return query.get().then(_parseReviews);
  }

  List<Review> _parseReviews(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => Review.fromFirestore(d.data(), d.id)).toList();

  // ----- Visit logs -----

  Future<void> addVisit({
    required String shopId,
    required String userId,
    required String userEmail,
    required String note,
    List<String> tags = const [],
  }) async {
    await shopRef(shopId).collection('visits').add({
      'userId': userId,
      'userEmail': userEmail,
      'note': note,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
