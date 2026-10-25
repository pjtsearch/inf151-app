import 'package:flutter/material.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../utils/goal_date_utils.dart';
import 'child_avatar.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.child,
    required this.isPast,
    required this.onCopy,
    required this.onDelete,
    required this.onPrint,
  });

  final Goal goal;
  final Child? child;
  final bool isPast;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tint = colors.primaryContainer;
    final endDate = goal.endDate.subtract(const Duration(days: 1));
    final totalTasks = goal.totalTasks;
    final completedTasks = goal.completedTasks.clamp(0, totalTasks);
    final progress = goal.progress;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (child != null)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          4,
                          4,
                          12,
                          4,
                        ),
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChildAvatar(child: child!, radius: 12),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                child!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Make a copy',
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (!isPast)
                      IconButton(
                        tooltip: 'Print punch card',
                        onPressed: onPrint,
                        icon: const Icon(Icons.print_outlined, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Goal options',
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (action) {
                        if (action == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              goal.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (goal.reward.label.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Reward · ${goal.reward.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: colors.onPrimaryContainer,
              backgroundColor: colors.surfaceContainerHighest,
              trackGap: 0,
              stopIndicatorRadius: 0,
              semanticsLabel:
                  '${goal.title}: $completedTasks of $totalTasks completed',
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '$completedTasks / $totalTasks completed',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${isPast ? 'Ended on' : 'Ends on'} ${formatDate(endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
