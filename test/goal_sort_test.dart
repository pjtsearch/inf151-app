import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/goal_sort.dart';
import 'package:inf151_app/services/goal_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Goal> _goals() {
  final first = Goal(
    id: 'a',
    childId: 'alex',
    title: 'First',
    frequency: 1,
    frequencyUnit: FrequencyUnit.day,
    duration: 10,
    durationUnit: DurationUnit.day,
    startDate: DateTime(2026, 1, 1),
    createdAt: DateTime(2025, 12, 1, 10),
    completedTasks: 2,
  );
  return [
    first,
    first.copyWith(
      id: 'b',
      duration: 4,
      completedTasks: 1,
      createdAt: DateTime(2025, 12, 3, 10),
    ),
    first.copyWith(
      id: 'c',
      duration: 8,
      completedTasks: 4,
      createdAt: DateTime(2025, 12, 2, 10),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final expectedOrders = {
    GoalSortBy.endDate: ['b', 'c', 'a'],
    GoalSortBy.creationDate: ['a', 'c', 'b'],
    GoalSortBy.progress: ['a', 'b', 'c'],
  };
  for (final by in GoalSortBy.values) {
    for (final descending in [false, true]) {
      test('${by.label} sorts ${descending ? 'descending' : 'ascending'}', () {
        final goals = _goals()
          ..sort(GoalSort(by: by, descending: descending).compare);
        final expected = expectedOrders[by]!;
        expect(
          goals.map((goal) => goal.id),
          descending ? expected.reversed : expected,
        );
      });
    }
  }

  test('progress is a bounded percentage and handles goals with no tasks', () {
    final goals = _goals();
    expect(goals.map((goal) => goal.progress), [0.2, 0.25, 0.5]);
    expect(goals.first.copyWith(completedTasks: -1).progress, 0);
    expect(goals.first.copyWith(completedTasks: 100).progress, 1);
    expect(goals.first.copyWith(duration: 0).progress, 0);
  });

  test('equal sort values use creation time and ID for a consistent order', () {
    final a = _goals().first;
    final b = a.copyWith(
      id: 'b',
      createdAt: a.createdAt.add(const Duration(hours: 1)),
    );
    final c = b.copyWith(id: 'c');
    final goals = [c, a, b]..sort(const GoalSort().compare);
    expect(goals.map((goal) => goal.id), ['a', 'b', 'c']);
    goals.sort(const GoalSort(descending: true).compare);
    expect(goals.map((goal) => goal.id), ['c', 'b', 'a']);
  });

  test(
    'creation time survives storage and changes to the goal schedule',
    () async {
      SharedPreferences.setMockInitialValues({});
      final goal = _goals().first;
      final rescheduled = goal.copyWith(startDate: DateTime(2026, 2, 1));
      expect(rescheduled.createdAt, goal.createdAt);
      await GoalStorage().save([rescheduled]);
      expect((await GoalStorage().load()).single.createdAt, goal.createdAt);
    },
  );

  test(
    'sort preference defaults to earliest end date and survives a reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = GoalStorage();
      final initial = await storage.loadSort();
      expect(initial.by, GoalSortBy.endDate);
      expect(initial.descending, isFalse);
      await storage.saveSort(
        const GoalSort(by: GoalSortBy.progress, descending: true),
      );
      final restored = await GoalStorage().loadSort();
      expect(restored.by, GoalSortBy.progress);
      expect(restored.descending, isTrue);
    },
  );
}
