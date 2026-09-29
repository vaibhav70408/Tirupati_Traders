import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/admin.dart';
import '../../domain/repositories/admin_repository.dart';

/// Firestore-backed [AdminRepository].
///
/// Expected Firestore structure:
///   collection: admins
///   document id: normalized phone number (e.g. +919319039228)
///   fields: name (string), isActive (bool, optional)
class FirestoreAdminRepository implements AdminRepository {
  final FirebaseFirestore _firestore;

  FirestoreAdminRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('admins');

  @override
  Future<List<Admin>> getActiveAdmins() async {
    final snap = await _col.where('isActive', isEqualTo: true).get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<bool> isActiveAdmin(String phoneNumber) async {
    final normalized = Admin.normalize(phoneNumber);
    final doc = await _col.doc(normalized).get();
    if (!doc.exists) return false;
    final data = doc.data();
    return (data?['isActive'] as bool? ?? true);
  }

  Admin _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Admin(
      phoneNumber: Admin.normalize(doc.id),
      name: (data['name'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}
