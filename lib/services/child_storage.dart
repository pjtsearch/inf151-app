import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/child.dart';

class ChildStorage {
  static const _key = 'children';

  Future<List<Child>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final data = preferences.getString(_key);
    if (data == null) return [];

    try {
      return (jsonDecode(data) as List<dynamic>)
          .map((item) => Child.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> save(List<Child> children) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode(children.map((child) => child.toJson()).toList()),
    );
    if (!saved) throw StateError('Could not save children.');
  }
}
