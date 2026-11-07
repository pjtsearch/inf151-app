import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/child.dart';
import '../utils/firestore_photo.dart';

/// Children are independent Firestore documents. The parent document stores
/// the ordered list of child IDs the signed-in parent can access.
class ChildStorage {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _parentId => _auth.currentUser?.uid ??
      (throw StateError('A parent must be signed in to load children.'));

  CollectionReference<Map<String, dynamic>> get _children =>
      _db.collection('children');

  Future<List<Child>> load() async {
    final parentId = _parentId;
    final parent = await _db.collection('parents').doc(parentId).get();
    final ids = (parent.data()?['childIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];

    final snapshots = await Future.wait(
      ids.map((id) => _children.doc(id).get()),
    );
    return [
      for (final snapshot in snapshots)
        if (snapshot.exists &&
            ((snapshot.data()?['parentIds'] as List<dynamic>?) ?? const [])
                .contains(parentId))
          Child.fromJson({...snapshot.data()!, 'id': snapshot.id}),
    ];
  }

  Future<Child?> loadById(String id) async {
    if (id.isEmpty || id.contains('/')) return null;
    final snapshot = await _children.doc(id).get();
    if (!snapshot.exists) return null;
    return Child.fromJson({...snapshot.data()!, 'id': snapshot.id});
  }

  Future<void> linkToCurrentParent(String childId) async {
    if (childId.isEmpty || childId.contains('/')) {
      throw const FormatException('Invalid child ID.');
    }
    final parentId = _parentId;
    final batch = _db.batch();
    batch.update(_children.doc(childId), {
      'parentIds': FieldValue.arrayUnion([parentId]),
    });
    batch.set(
      _db.collection('parents').doc(parentId),
      {'childIds': FieldValue.arrayUnion([childId])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Removes this parent from a child. If no other parents remain, deletes the
  /// child and this parent's goals (tasks) associated with it.
  Future<bool> deleteForCurrentParent(String childId) async {
    final parentId = _parentId;
    final childRef = _children.doc(childId);
    final parentRef = _db.collection('parents').doc(parentId);
    final childSnapshot = await childRef.get();
    if (!childSnapshot.exists) {
      await parentRef.set(
        {'childIds': FieldValue.arrayRemove([childId])},
        SetOptions(merge: true),
      );
      return true;
    }

    final parentIds = (childSnapshot.data()?['parentIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toSet()
      ..remove(parentId);
    final batch = _db.batch();
    batch.set(parentRef, {'childIds': FieldValue.arrayRemove([childId])}, SetOptions(merge: true));
    if (parentIds.isNotEmpty) {
      batch.update(childRef, {'parentIds': parentIds.toList()});
      await batch.commit();
      return false;
    }

    batch.delete(childRef);
    final goals = await _db
        .collection('goals')
        .where('parentId', isEqualTo: parentId)
        .where('childId', isEqualTo: childId)
        .get();
    for (final goal in goals.docs) {
      batch.delete(goal.reference);
    }
    await batch.commit();
    return true;
  }

  Future<void> save(List<Child> children) async {
    final parentId = _parentId;
    final parentRef = _db.collection('parents').doc(parentId);
    final current = await _children
        .where('parentIds', arrayContains: parentId)
        .get();
    final currentById = {for (final doc in current.docs) doc.id: doc};
    final nextIds = children.map((child) => child.id).toSet();
    final batch = _db.batch();

    for (final child in children) {
      final photoBytes = child.photoBytes;
      if (photoBytes != null && photoBytes.length > maxFirestorePhotoBytes) {
        throw StateError('Child photos must be smaller than 650 KB.');
      }
      final existingParents = (currentById[child.id]?.data()['parentIds']
                  as List<dynamic>? ??
              const [])
          .whereType<String>()
          .toSet();
      existingParents.add(parentId);
      batch.set(_children.doc(child.id), {
        'parentIds': existingParents.toList(),
        'name': child.name,
        'photoData': photoBytes == null ? null : base64Encode(photoBytes),
        'color': child.color.name,
      });
    }
    for (final document in current.docs) {
      if (!nextIds.contains(document.id)) {
        final parentIds = (document.data()['parentIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toSet()
          ..remove(parentId);
        if (parentIds.isEmpty) {
          batch.delete(document.reference);
        } else {
          batch.update(document.reference, {'parentIds': parentIds.toList()});
        }
      }
    }
    batch.set(parentRef, {'childIds': children.map((child) => child.id).toList()}, SetOptions(merge: true));
    await batch.commit();
  }
}
