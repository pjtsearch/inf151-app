import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal.dart';

class GoalStorage {
  static const _key = 'goals';

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
