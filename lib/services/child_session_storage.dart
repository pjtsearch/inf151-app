import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/child.dart';

/// Stores the selected child for an anonymous, read-only child session.
class ChildSessionStorage {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw StateError('A child session must be signed in.');
    }
    return user;
  }

  Future<String?> loadChildId() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return null;
    final profile = await _db.collection('parents').doc(user.uid).get();
    return profile.data()?['childSessionId'] as String?;
  }

  Future<void> activate(String childId) async {
    if (childId.isEmpty || childId.contains('/')) {
      throw const FormatException('Invalid child QR code.');
    }
    final user = _user;
    await _db
        .collection('children')
        .doc(childId)
        .collection('childSessions')
        .doc(user.uid)
        .set({'createdAt': FieldValue.serverTimestamp()});
    await _db.collection('parents').doc(user.uid).set(
      {'childSessionId': childId},
      SetOptions(merge: true),
    );
  }

  Future<Child?> loadChild(String childId) async {
    final snapshot = await _db.collection('children').doc(childId).get();
    if (!snapshot.exists) return null;
    return Child.fromJson({...snapshot.data()!, 'id': snapshot.id});
  }

  Future<void> clear() async {
    final user = _user;
    final profileRef = _db.collection('parents').doc(user.uid);
    final profile = await profileRef.get();
    final childId = profile.data()?['childSessionId'] as String?;
    if (childId != null) {
      await _db
          .collection('children')
          .doc(childId)
          .collection('childSessions')
          .doc(user.uid)
          .delete();
    }
    if (profile.exists && childId != null) {
      await profileRef.update({'childSessionId': FieldValue.delete()});
    }
  }
}
