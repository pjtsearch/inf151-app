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
    final parentData = (await _parent.get()).data();
    final childIds = (parentData?['childIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final documents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final childId in childIds) {
      final snapshot = await _goals
          .where('childId', isEqualTo: childId)
          .get();
      documents.addAll(snapshot.docs);
    }
    return documents
        .map((doc) => Goal.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> save(List<Goal> goals) async {
    final parentId = _parentId;
    final batch = _db.batch();
    for (final goal in goals) {
      final creatorId = goal.creatorId.isEmpty ? parentId : goal.creatorId;
      if (creatorId != parentId) {
        batch.update(_goals.doc(goal.id), {'completedTasks': goal.completedTasks});
        continue;
      }
      batch.set(_goals.doc(goal.id), {
        ...goal.toJson(),
        'parentId': creatorId,
        'creatorName': goal.creatorName.isNotEmpty
            ? goal.creatorName
            : creatorId == parentId
            ? (_auth.currentUser?.displayName ?? 'A parent')
            : 'Another parent',
      });
    }
    await batch.commit();
  }

  Future<void> deleteGoals(Iterable<String> goalIds) async {
    final ids = goalIds.toSet().toList();
    for (var start = 0; start < ids.length; start += 500) {
      final batch = _db.batch();
      for (final id in ids.skip(start).take(500)) {
        batch.delete(_goals.doc(id));
      }
      await batch.commit();
    }
  }
}
