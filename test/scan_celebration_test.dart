import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/screens/goals_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final cancel in [false, true]) {
    testWidgets(cancel ? 'cancelled scan does not celebrate or save' : 'partial scan saves without celebrating', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final goal = Goal(
        id: 'scan-test', title: 'Walk', frequency: 1,
        frequencyUnit: FrequencyUnit.day, duration: 7,
        durationUnit: DurationUnit.day, startDate: DateTime.now(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('goals', jsonEncode([goal.toJson()]));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const GoalsPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan card'));
      // Return a scanner result without needing physical camera hardware.
      navigator.currentState!.pop(cancel ? null : goal.copyWith(completedTasks: 1));
      await tester.pumpAndSettle();
      expect(find.byType(Confetti), findsNothing);
      final stored = jsonDecode(prefs.getString('goals')!) as List<dynamic>;
      expect(stored.single['completedTasks'], cancel ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
