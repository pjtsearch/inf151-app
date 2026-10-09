import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../utils/goal_date_utils.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.isPast,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onPrint,
  });

  final Goal goal;
  final bool isPast;
  final VoidCallback onEdit;
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

    return Card(
      child: Padding(
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
                  if (goal.reward.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Reward: ${goal.reward}',
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
                  if (isPast) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          goal.isCompleted
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: goal.isCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          goal.isCompleted ? 'Completed' : 'Not completed',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isPast)
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
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (!isPast)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
