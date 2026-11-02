import 'package:flutter/material.dart';
import 'package:onboarding_overlay/onboarding_overlay.dart';

List<OnboardingStep> goalOnboardingSteps({
  required FocusNode childrenFocus,
  required FocusNode addGoalFocus,
  required FocusNode goalsFocus,
  required FocusNode scanFocus,
}) {
  final steps = [
    (
      childrenFocus,
      'Add your children',
      'Add each child’s name, photo and color here. Use their chips to filter goals.',
    ),
    (
      addGoalFocus,
      'Create a goal',
      'Choose a task, how often to do it, how long to keep going and a reward you will give.',
    ),
    (
      goalsFocus,
      'Print cards together',
      'Hold a goal to select it, then tap more goals and print their cards together.',
    ),
    (
      scanFocus,
      'Scan your progress',
      'After completed tasks are punched out on a printed card, scan it here to review and save check-ins.',
    ),
  ];

  return [
    for (final (index, (focusNode, title, body)) in steps.indexed)
      OnboardingStep(
        focusNode: focusNode,
        titleText: title,
        bodyText: body,
        margin: const EdgeInsets.all(4),
        overlayColor: const Color(0xB3000000),
        labelBoxMargin: const EdgeInsets.symmetric(horizontal: 16),
        labelBoxPadding: EdgeInsets.zero,
        stepBuilder: (context, info) =>
            _GuideStep(info: info, index: index, count: steps.length),
      ),
  ];
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.info,
    required this.index,
    required this.count,
  });

  final OnboardingStepRenderInfo info;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = index == count - 1;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${index + 1} of $count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(info.titleText, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(info.bodyText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(onPressed: info.close, child: const Text('Skip')),
                FilledButton(
                  onPressed: last ? info.close : info.nextStep,
                  child: Text(last ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
