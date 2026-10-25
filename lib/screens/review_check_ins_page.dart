import 'package:flutter/material.dart';

import '../models/child.dart';
import '../models/punch_card_progress.dart';
import '../widgets/child_avatar.dart';

class ReviewCheckInsPage extends StatelessWidget {
  const ReviewCheckInsPage({super.key, required this.progress, this.child});

  final PunchCardProgress progress;
  final Child? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final goal = progress.goal;
    final updatedGoal = progress.updatedGoal;
    final isComplete = updatedGoal.hasCompletedAllTasks;
    final summaryForeground = isComplete
        ? colors.onPrimaryContainer
        : colors.onSecondaryContainer;
    final reward = goal.reward.label.trim();
    final matchedChild = child;
    final progressLabel = matchedChild == null
        ? 'this progress'
        : '${matchedChild.name}’s progress';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text('Review check-ins', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Confirm what’s on the physical card.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      if (matchedChild != null) ...[
                        ChildAvatar(child: matchedChild, radius: 22),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchedChild == null
                                  ? 'Matched goal'
                                  : 'Matched to ${matchedChild.name}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              goal.title,
                              style: TextStyle(
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check-ins ${progress.cardStart + 1}–${progress.cardEnd + 1} of ${goal.totalTasks}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CountRow(
                  label: 'Previously recorded on this card',
                  count: progress.previouslyRecordedOnCard,
                  total: progress.holeCount,
                ),
                const SizedBox(height: 12),
                _CountRow(
                  label: 'Detected on this card',
                  count: progress.detectedCount,
                  total: progress.holeCount,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(isComplete ? 20 : 16),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? colors.primaryContainer
                        : colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isComplete)
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: summaryForeground,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Goal complete!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: summaryForeground,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${progress.newCheckIns} new check-in${progress.newCheckIns == 1 ? '' : 's'}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: summaryForeground,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        isComplete
                            ? 'All ${goal.totalTasks} check-ins completed! '
                                  'Confirm below to save $progressLabel.'
                            : 'The goal total becomes ${progress.completedTasksAfter} / ${goal.totalTasks}. '
                                  'Previously recorded marks are not counted again.',
                        style: TextStyle(color: summaryForeground),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: updatedGoal.progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        semanticsLabel:
                            'Goal progress after saving: ${progress.completedTasksAfter} of ${goal.totalTasks} completed',
                      ),
                      if (isComplete && reward.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.redeem,
                                size: 40,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reward',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reward,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    onPressed: () => Navigator.pop(context, updatedGoal),
                    child: const Text('Confirm & Save Progress'),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retake Photo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('$count / $total check-ins'),
        ),
      ],
    );
  }
}
