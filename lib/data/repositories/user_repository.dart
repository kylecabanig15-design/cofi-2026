import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cofi/models/user_model.dart';

/// Read/write access for user documents. The only place outside auth flows
/// that should touch the users collection.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) {
    return userRef(uid).snapshots().map(
        (d) => d.exists ? AppUser.fromFirestore(d.data()!, uid) : null);
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await userRef(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.data()!, uid);
  }

  Future<void> updateFields(String uid, Map<String, dynamic> fields) async {
    await userRef(uid).update(fields);
  }

  Future<void> setField(String uid, String field, Object value) async {
    await updateFields(uid, {field: value});
  }

  Future<void> addToBookmark(String uid, String shopId) =>
      _arrayUnion(uid, 'bookmarks', shopId);

  Future<void> removeFromBookmark(String uid, String shopId) =>
      _arrayRemove(uid, 'bookmarks', shopId);

  Future<void> addToVisited(String uid, String shopId) =>
      _arrayUnion(uid, 'visited', shopId);

  Future<void> removeFromVisited(String uid, String shopId) =>
      _arrayRemove(uid, 'visited', shopId);

  Future<void> _arrayUnion(
      String uid, String field, String value) async {
    await userRef(uid).set({
      field: FieldValue.arrayUnion([value]),
    }, SetOptions(merge: true));
  }

  Future<void> _arrayRemove(
      String uid, String field, String value) async {
    await userRef(uid).set({
      field: FieldValue.arrayRemove([value]),
    }, SetOptions(merge: true));
  }
}
