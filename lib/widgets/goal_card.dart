import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../utils/goal_date_utils.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.isPast,
    required this.onCopy,
    required this.onDelete,
    required this.onPrint,
  });

  final Goal goal;
  final bool isPast;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final durationName = switch (goal.durationUnit) {
      DurationUnit.day => 'day',
      DurationUnit.week => 'week',
      DurationUnit.month => 'month',
    };
    final endDate = goal.endDate.subtract(const Duration(days: 1));

    final totalTasks = goal.totalTasks;
    final completedTasks = goal.completedTasks.clamp(0, totalTasks);
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (goal.reward.label.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Reward: ${goal.reward.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    '${goal.frequencyDescription} · ${goal.duration} $durationName${goal.duration == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${isPast ? 'Ended' : 'Ends'} ${formatDate(endDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedTasks tasks/$totalTasks completed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Make a copy',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
            ),
            if (!isPast)
              IconButton(
                tooltip: 'Print punch card',
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
              ),
            PopupMenuButton<String>(
              tooltip: 'Goal options',
              onSelected: (action) {
                if (action == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
        ),
    );
  }
}
