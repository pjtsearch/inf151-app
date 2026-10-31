import '../models/child.dart';
import '../models/goal.dart';

List<Goal> buildExampleGoals(List<Child> children, DateTime now) {
  assert(children.isNotEmpty);
  final start = DateTime(now.year, now.month, now.day);
  final id = now.microsecondsSinceEpoch;
  return [
    Goal(
      id: 'example-reading-$id',
      childId: children.first.id,
      title: 'Read for 20 minutes',
      frequency: 1,
      frequencyUnit: FrequencyUnit.day,
      duration: 2,
      durationUnit: DurationUnit.week,
      startDate: start,
      createdAt: now,
      reward: const FreeTextReward('Choose a new book'),
      completedTasks: 3,
    ),
    Goal(
      id: 'example-tidying-$id',
      childId: children[1 % children.length].id,
      title: 'Tidy the bedroom',
      frequency: 2,
      frequencyUnit: FrequencyUnit.week,
      duration: 4,
      durationUnit: DurationUnit.week,
      startDate: start,
      createdAt: now,
      reward: const FreeTextReward('A family movie night'),
      completedTasks: 1,
    ),
    Goal(
      id: 'example-kindness-$id',
      childId: children[2 % children.length].id,
      title: 'Do something kind',
      frequency: 4,
      frequencyUnit: FrequencyUnit.month,
      duration: 3,
      durationUnit: DurationUnit.month,
      startDate: start,
      createdAt: now,
      reward: const FreeTextReward('A special day out'),
      completedTasks: 1,
    ),
  ];
}
