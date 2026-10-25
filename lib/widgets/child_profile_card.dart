import 'package:flutter/material.dart';

import '../models/child.dart';

class ChildProfileCard extends StatelessWidget {
  const ChildProfileCard({
    super.key,
    required this.child,
    required this.activeGoalCount,
    this.onTap,
    this.isDropTarget = false,
  });

  final Child child;
  final int activeGoalCount;
  final VoidCallback? onTap;
  final bool isDropTarget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.primaryContainer.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          child.name.characters.firstOrNull?.toUpperCase() ?? '?',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(color: colors.onPrimaryContainer),
        ),
      ),
    );

    return Material(
      color: isDropTarget
          ? colors.primaryContainer
          : Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDropTarget
            ? BorderSide(color: colors.onPrimaryContainer, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: child.photoBytes == null
                      ? placeholder
                      : Image.memory(
                          child.photoBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => placeholder,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                child.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$activeGoalCount active goal${activeGoalCount == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
