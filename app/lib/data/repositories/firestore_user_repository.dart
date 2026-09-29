import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';

/// Firestore-backed [UserRepository].
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  AppUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final created = data['createdAt'];
    return AppUser(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] as String?,
      name: data['name'] as String?,
      address: data['address'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<AppUser?> getUserByPhone(String phoneNumber) async {
    final snap = await _users
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _fromDoc(snap.docs.first);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    await _users.doc(user.uid).set({
      'phoneNumber': user.phoneNumber,
      if (user.name != null) 'name': user.name,
      if (user.address != null) 'address': user.address,
      'createdAt': user.createdAt ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromDoc(doc);
    });
  }
}
