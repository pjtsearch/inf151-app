import 'package:flutter/material.dart';

class EmptyGoals extends StatelessWidget {
  const EmptyGoals({super.key, required this.isPast});

  final bool isPast;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPast ? Icons.history_rounded : Icons.flag_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            isPast ? 'No past goals yet' : 'No goals yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            isPast
                ? 'Finished goals will appear here.'
                : 'Add a goal to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
