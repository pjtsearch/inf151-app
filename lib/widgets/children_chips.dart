import 'package:flutter/material.dart';

import '../models/child.dart';
import 'child_avatar.dart';

class ChildrenChips extends StatelessWidget {
  const ChildrenChips({
    super.key,
    required this.children,
    required this.selectedChildId,
    required this.onSelected,
    required this.onAddChild,
    this.showAllChildren = false,
    this.padding = EdgeInsets.zero,
  });

  final List<Child> children;
  final String? selectedChildId;
  final ValueChanged<String?> onSelected;
  final VoidCallback? onAddChild;
  final bool showAllChildren;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          if (showAllChildren) ...[
            ChoiceChip(
              avatar: Icon(
                Icons.people_outline,
                size: 20,
                color: selectedChildId == null
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              label: const Text('All children'),
              selected: selectedChildId == null,
              selectedColor: colors.primary,
              labelStyle: TextStyle(
                color: selectedChildId == null
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              side: selectedChildId == null ? BorderSide.none : null,
              showCheckmark: false,
              onSelected: (_) => onSelected(null),
            ),
            const SizedBox(width: 8),
          ],
          for (final child in children) ...[
            ChoiceChip(
              avatar: ChildAvatar(child: child),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(child.name, overflow: TextOverflow.ellipsis),
              ),
              selected: selectedChildId == child.id,
              selectedColor: colors.primary,
              labelStyle: TextStyle(
                color: selectedChildId == child.id
                    ? colors.onPrimary
                    : colors.onSurfaceVariant,
              ),
              side: selectedChildId == child.id ? BorderSide.none : null,
              showCheckmark: false,
              onSelected: (_) => onSelected(child.id),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: Icon(Icons.add, size: 20, color: colors.onSurfaceVariant),
            label: const Text('Add child'),
            onPressed: onAddChild,
          ),
        ],
      ),
    );
  }
}
