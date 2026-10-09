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
    expect(goal.isPastOn(DateTime(2025, 2, 28)), isFalse);
    expect(goal.isPastOn(DateTime(2025, 3, 1)), isTrue);
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
      isCompleted: true,
    );
    final storage = GoalStorage();

    await storage.save([goal]);

    expect((await storage.load()).single.toJson(), goal.toJson());
  });

  test('a completed goal is past before its end date', () {
    final goal = Goal(
      id: 'goal-2',
      title: 'Read',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.month,
      startDate: DateTime(2030, 1, 1),
      isCompleted: true,
    );

    expect(goal.isPastOn(DateTime(2026, 10, 9)), isTrue);
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

    await tester.tap(find.byTooltip('Goal options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('completed goals appear in Past with a completion indicator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final goal = Goal(
      id: 'goal-3',
      title: 'Read a book',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.month,
      startDate: DateTime(2030, 1, 1),
      isCompleted: true,
    );
    await GoalStorage().save([goal]);

    await tester.pumpWidget(const GoalApp());
    await tester.pumpAndSettle();
    expect(find.text('Read a book'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    expect(find.text('Read a book'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    await tester.tap(find.byTooltip('Goal options'));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
  });
}
