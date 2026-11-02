import 'package:flutter_test/flutter_test.dart';
import 'package:inf151_app/models/goal.dart';
import 'package:inf151_app/models/punch_card_progress.dart';

Goal _goal({int completed = 0, int total = 14}) => Goal(
  id: 'reading',
  childId: 'emma',
  title: 'Read for 20 minutes',
  frequency: 1,
  frequencyUnit: FrequencyUnit.day,
  duration: total,
  durationUnit: DurationUnit.day,
  startDate: DateTime(2026, 10, 24),
  completedTasks: completed,
);

void main() {
  test('a partially punched card adds progress without filling the card', () {
    final goal = _goal();
    final scan = PunchCardProgress(
      goal: goal,
      cardStart: 0,
      cardEnd: 13,
      detectedCount: 5,
    );
    expect(scan.previouslyRecordedOnCard, 0);
    expect(scan.newCheckIns, 5);
    expect(scan.updatedGoal.completedTasks, 5);
    expect(goal.completedTasks, 0);
  });

  test('rescanning adds only new marks and never reduces saved progress', () {
    final goal = _goal(completed: 8);
    final scan = PunchCardProgress(
      goal: goal,
      cardStart: 0,
      cardEnd: 13,
      detectedCount: 10,
    );
    expect(scan.previouslyRecordedOnCard, 8);
    expect(scan.newCheckIns, 2);
    expect(scan.completedTasksAfter, 10);

    for (final detected in [10, 8, 0]) {
      final rescan = PunchCardProgress(
        goal: scan.updatedGoal,
        cardStart: 0,
        cardEnd: 13,
        detectedCount: detected,
      );
      expect(rescan.newCheckIns, 0);
      expect(rescan.completedTasksAfter, 10);
    }
  });

  test('later cards account for their offset within the goal', () {
    final scan = PunchCardProgress(
      goal: _goal(completed: 18, total: 28),
      cardStart: 14,
      cardEnd: 27,
      detectedCount: 8,
    );
    expect(scan.previouslyRecordedOnCard, 4);
    expect(scan.newCheckIns, 4);
    expect(scan.completedTasksAfter, 22);
  });

  test('an earlier completed card does not add duplicate progress', () {
    final scan = PunchCardProgress(
      goal: _goal(completed: 18, total: 28),
      cardStart: 0,
      cardEnd: 13,
      detectedCount: 14,
    );
    expect(scan.previouslyRecordedOnCard, 14);
    expect(scan.newCheckIns, 0);
    expect(scan.completedTasksAfter, 18);
  });

  test('a final card with fewer holes can complete the goal', () {
    final scan = PunchCardProgress(
      goal: _goal(completed: 29, total: 31),
      cardStart: 28,
      cardEnd: 30,
      detectedCount: 3,
    );
    expect(scan.holeCount, 3);
    expect(scan.previouslyRecordedOnCard, 1);
    expect(scan.newCheckIns, 2);
    expect(scan.completedTasksAfter, 31);
    expect(scan.updatedGoal.hasCompletedAllTasks, isTrue);
  });

  test('zero detected marks produces an unchanged proposal', () {
    final scan = PunchCardProgress(
      goal: _goal(),
      cardStart: 0,
      cardEnd: 13,
      detectedCount: 0,
    );
    expect(scan.newCheckIns, 0);
    expect(scan.completedTasksAfter, 0);
  });

  test('future cards are rejected until previous cards are completed', () {
    expect(
      () => PunchCardProgress(
        goal: _goal(completed: 8, total: 28),
        cardStart: 14,
        cardEnd: 27,
        detectedCount: 8,
      ),
      throwsArgumentError,
    );
  });

  test('invalid card ranges and impossible detected counts are rejected', () {
    for (final (start, end, count) in [
      (-1, 13, 8),
      (0, -1, 0),
      (0, 14, 8),
      (0, 13, -1),
      (0, 13, 15),
    ]) {
      expect(
        () => PunchCardProgress(
          goal: _goal(),
          cardStart: start,
          cardEnd: end,
          detectedCount: count,
        ),
        throwsArgumentError,
      );
    }
  });
}
