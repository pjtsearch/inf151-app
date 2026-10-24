import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';
import '../models/goal_sort.dart';

class GoalStorage {
  static const _key = 'goals';
  static const _sortKey = 'goal_sort';

  Future<GoalSort> loadSort() async {
    final preferences = await SharedPreferences.getInstance();
    final data = preferences.getString(_sortKey);
    if (data == null) return const GoalSort();
    try {
      return GoalSort.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } on FormatException {
      return const GoalSort();
    } on TypeError {
      return const GoalSort();
    }
  }

  Future<void> saveSort(GoalSort sort) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _sortKey,
      jsonEncode(sort.toJson()),
    );
    if (!saved) throw StateError('Could not save sorting preference.');
  }

  Future<List<Goal>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final data = preferences.getString(_key);
    if (data == null) return [];

    try {
      return (jsonDecode(data) as List<dynamic>)
          .map((item) => Goal.fromJson(item as Map<String, dynamic>))
          .map((item) => item.copyWith(completedTasks: 0)) // TODO: Remove
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> save(List<Goal> goals) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(goals.map((goal) => goal.toJson()).toList()),
    );
  }
}
