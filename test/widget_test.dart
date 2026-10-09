import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/main.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('month duration ends on the corresponding calendar day', () {
    final goal = Goal(
      id: 'goal-1',
      title: 'Walk',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.month,
      startDate: DateTime(2025, 1, 31),
    );

    expect(goal.endDate, DateTime(2025, 2, 28));
    expect(goal.isPastOn(DateTime(2025, 2, 27)), isFalse);
    expect(goal.isPastOn(DateTime(2025, 2, 28)), isTrue);
  });

  test('goals survive a storage reload', () async {
    SharedPreferences.setMockInitialValues({});
    final goal = Goal(
      id: 'goal-1',
      title: 'Mow the lawn',
      frequency: 1,
      frequencyUnit: FrequencyUnit.week,
      duration: 6,
      durationUnit: DurationUnit.month,
      startDate: DateTime(2025, 1, 1),
    );
    final storage = GoalStorage();

    await storage.save([goal]);

    expect((await storage.load()).single.toJson(), goal.toJson());
  });

  testWidgets('a new goal can be added and remains stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const GoalApp());
    await tester.pumpAndSettle();

    expect(find.text('No goals yet'), findsOneWidget);
    await tester.tap(find.text('Add goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Take a walk');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Coffee with a friend',
    );
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(find.text('Take a walk'), findsOneWidget);
    expect(find.text('Reward: Coffee with a friend'), findsOneWidget);
    expect(find.text('1 time per day · 1 week'), findsOneWidget);
    expect((await GoalStorage().load()).single.reward, 'Coffee with a friend');
  });
}
