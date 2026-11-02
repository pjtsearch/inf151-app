import 'goal.dart';

/// A scan's proposed progress, accounting for marks saved from the same card.
class PunchCardProgress {
  PunchCardProgress({
    required this.goal,
    required this.cardStart,
    required this.cardEnd,
    required this.detectedCount,
  }) {
    if (cardStart < 0 || cardEnd < cardStart || cardEnd >= goal.totalTasks) {
      throw ArgumentError('The card range must be within the goal.');
    }
    if (cardStart > goal.completedTasks) {
      throw ArgumentError('Complete the previous cards first.');
    }
    if (detectedCount < 0 || detectedCount > holeCount) {
      throw RangeError.range(detectedCount, 0, holeCount, 'detectedCount');
    }
  }

  final Goal goal;
  final int cardStart;
  final int cardEnd;
  final int detectedCount;

  int get holeCount => cardEnd - cardStart + 1;

  int get previouslyRecordedOnCard =>
      (goal.completedTasks - cardStart).clamp(0, holeCount);

  int get newCheckIns =>
      (detectedCount - previouslyRecordedOnCard).clamp(0, holeCount);

  int get completedTasksAfter => goal.completedTasks + newCheckIns;

  Goal get updatedGoal => goal.copyWith(completedTasks: completedTasksAfter);
}
