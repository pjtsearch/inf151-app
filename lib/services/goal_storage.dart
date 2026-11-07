import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/goal.dart';
import '../models/goal_sort.dart';

/// Goals live as independent documents and carry both parentId and childId.
class GoalStorage {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _parentId => _auth.currentUser?.uid ??
      (throw StateError('A parent must be signed in to load goals.'));

  DocumentReference<Map<String, dynamic>> get _parent =>
      _db.collection('parents').doc(_parentId);

  CollectionReference<Map<String, dynamic>> get _goals =>
      _db.collection('goals');

  Future<GoalSort> loadSort() async {
    final data = (await _parent.get()).data()?['goalSort'];
    return data is Map<String, dynamic>
        ? GoalSort.fromJson(data)
        : const GoalSort();
  }

  Future<void> saveSort(GoalSort sort) =>
      _parent.set({'goalSort': sort.toJson()}, SetOptions(merge: true));

  Future<bool> loadOnboardingSeen() async =>
      (await _parent.get()).data()?['onboardingSeen'] == true;

  Future<void> saveOnboardingSeen() =>
      _parent.set({'onboardingSeen': true}, SetOptions(merge: true));

  Future<List<Goal>> load() async {
    final parentId = _parentId;
    final snapshot = await _goals.where('parentId', isEqualTo: parentId).get();
    return snapshot.docs
        .map((doc) => Goal.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> save(List<Goal> goals) async {
    final parentId = _parentId;
    final current = await _goals.where('parentId', isEqualTo: parentId).get();
    final nextIds = goals.map((goal) => goal.id).toSet();
    final batch = _db.batch();
    for (final goal in goals) {
      batch.set(_goals.doc(goal.id), {
        ...goal.toJson(),
        'parentId': parentId,
      });
    }
    for (final document in current.docs) {
      if (!nextIds.contains(document.id)) batch.delete(document.reference);
    }
    await batch.commit();
  }
}
