import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/main.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/services/punch_card_pdf.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('punch count follows the goal frequency and duration', () {
    final dailyGoal = Goal(
      id: 'daily',
      title: 'Walk',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.week,
      startDate: DateTime(2026, 1, 1),
    );
    final weeklyGoal = dailyGoal.copyWith(
      frequency: 2,
      frequencyUnit: FrequencyUnit.week,
      duration: 2,
    );
    final monthlyGoal = dailyGoal.copyWith(
      frequencyUnit: FrequencyUnit.month,
      duration: 3,
      durationUnit: DurationUnit.month,
      startDate: DateTime(2025, 1, 31),
    );

    expect(punchCountFor(dailyGoal), 7);
    expect(punchCountFor(weeklyGoal), 4);
    expect(punchCountFor(monthlyGoal), 3);
  });

  test('punch-card layout uses seven columns and weekday labels', () {
    final dailyGoal = Goal(
      id: 'daily',
      title: 'Walk',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.week,
      startDate: DateTime(2026, 1, 1),
    );
    final weeklyGoal = dailyGoal.copyWith(frequencyUnit: FrequencyUnit.week);

    expect(punchCardColumnsPerRow, 7);
    expect(punchCardMaxRows, 2);
    expect(punchCardColumnLabels(dailyGoal), [
      'Th',
      'F',
      'Sa',
      'Su',
      'M',
      'T',
      'W',
    ]);
    expect(punchCardColumnLabels(weeklyGoal), [
      'W1',
      'W2',
      'W3',
      'W4',
      'W5',
      'W6',
      'W7',
    ]);
    expect(punchCardColumnLabels(dailyGoal, periodOffset: 7).first, 'Th');
    final monthlyGoal = dailyGoal.copyWith(
      frequencyUnit: FrequencyUnit.month,
      startDate: DateTime(2025, 12, 31),
    );
    final multipleDailyGoal = dailyGoal.copyWith(frequency: 3);
    expect(punchCardColumnLabels(monthlyGoal).take(3), ['Dec', 'Jan', 'Feb']);
    expect(
      List.generate(
        3,
        (index) => punchCardLabelForHole(multipleDailyGoal, index),
      ),
      ['Th', null, null],
    );
    expect(punchCardLabelForHole(multipleDailyGoal, 3), 'F');
    expect(punchCardLabelForHole(weeklyGoal.copyWith(frequency: 2), 1), isNull);
    expect(punchCardLabelForHole(weeklyGoal.copyWith(frequency: 2), 2), 'W2');
    expect(
      punchCardLabelForHole(monthlyGoal.copyWith(frequency: 2), 1),
      isNull,
    );
  });

  test('punch-card PDF is generated', () async {
    final goal = Goal(
      id: 'pdf',
      title: 'Walk',
      frequency: 3,
      frequencyUnit: FrequencyUnit.day,
      duration: 1,
      durationUnit: DurationUnit.week,
      startDate: DateTime(2026, 1, 1),
    );

    final bytes = await buildPunchCardPdf(goal);

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

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
    expect(find.byTooltip('Print punch card'), findsOneWidget);
    expect((await GoalStorage().load()).single.reward, 'Coffee with a friend');

    await tester.tap(find.byTooltip('Goal options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Print punch card'), findsNothing);
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

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Make a copy'));
    await tester.pumpAndSettle();

    expect(find.text('New goal'), findsOneWidget);
    expect(find.text('Save goal'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Read a book',
    );
    expect((await GoalStorage().load()), hasLength(1));

    await tester.enterText(find.byType(TextFormField).first, 'Read two books');
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(find.text('Read two books'), findsOneWidget);
    expect(find.text('Read a book'), findsNothing);
    final savedGoals = await GoalStorage().load();
    expect(savedGoals, hasLength(2));
    expect(savedGoals.last.title, 'Read two books');
    expect(savedGoals.last.isCompleted, isFalse);
  });
}
