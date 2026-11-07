import 'package:flutter/material.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../widgets/child_profile_card.dart';
import 'child_form_page.dart';
import 'link_child_qr_page.dart';

enum _AddChildChoice { create, link }

class ManageChildrenPage extends StatefulWidget {
  const ManageChildrenPage({
    super.key,
    required this.children,
    required this.onSave,
    this.onLink,
    required this.onReorder,
    this.goals = const [],
  });

  final List<Child> children;
  final Future<void> Function(Child child) onSave;
  final Future<Child> Function(String childId)? onLink;
  final Future<void> Function(List<Child> children) onReorder;
  final List<Goal> goals;

  @override
  State<ManageChildrenPage> createState() => _ManageChildrenPageState();
}

class _ManageChildrenPageState extends State<ManageChildrenPage> {
  late final List<Child> _children;
  String? _draggingChildId;
  bool _savingOrder = false;
  bool _linkingChild = false;
  EdgeDraggingAutoScroller? _autoScroller;

  @override
  void initState() {
    super.initState();
    _children = List.of(widget.children);
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    super.dispose();
  }

  Future<void> _editChild({Child? child}) async {
    if (_savingOrder || _linkingChild || _draggingChildId != null) return;
    final savedChild = await Navigator.of(context).push<Child>(
      MaterialPageRoute(
        builder: (_) => ChildFormPage(child: child, onSave: widget.onSave),
      ),
    );
    if (savedChild == null || !mounted) return;
    setState(() {
      final index = _children.indexWhere((item) => item.id == savedChild.id);
      if (index < 0) {
        _children.add(savedChild);
      } else {
        _children[index] = savedChild;
      }
    });
  }

  Future<void> _reorderChild(String childId, int targetIndex) async {
    final oldIndex = _children.indexWhere((child) => child.id == childId);
    if (_savingOrder || _linkingChild || oldIndex < 0 || oldIndex == targetIndex) {
      return;
    }
    final previousOrder = List<Child>.of(_children);
    setState(() {
      final child = _children.removeAt(oldIndex);
      _children.insert(targetIndex, child);
      _savingOrder = true;
    });
    try {
      await widget.onReorder(List<Child>.of(_children));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _children
          ..clear()
          ..addAll(previousOrder);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save child order. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _addChild() async {
    if (_savingOrder || _linkingChild || _draggingChildId != null) return;
    final choice = await showModalBottomSheet<_AddChildChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Create a new child'),
              onTap: () => Navigator.pop(context, _AddChildChoice.create),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Link an existing child'),
              subtitle: const Text('Scan their child ID QR code'),
              onTap: () => Navigator.pop(context, _AddChildChoice.link),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _AddChildChoice.create:
        await _editChild();
        break;
      case _AddChildChoice.link:
        await _linkExistingChild();
        break;
      case null:
        break;
    }
  }

  Future<void> _linkExistingChild() async {
    final childId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const LinkChildQrPage()),
    );
    if (childId == null || !mounted) return;
    if (_children.any((child) => child.id == childId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This child is already linked.')),
      );
      return;
    }

    setState(() => _linkingChild = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link this child?'),
          content: Text(
            'This will add child ID $childId to your Children list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Link child'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final onLink = widget.onLink;
      if (onLink == null) {
        throw StateError('Linking a child is unavailable.');
      }
      final linkedChild = await onLink(childId);
      if (!mounted) return;
      setState(() => _children.add(linkedChild));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${linkedChild.name} was linked.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not link child. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _linkingChild = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeCounts = <String, int>{};
    for (final goal in widget.goals) {
      if (!goal.isPastOn(now)) {
        activeCounts.update(
          goal.childId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_savingOrder && !_linkingChild,
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              const SliverAppBar.large(title: Text('Children'), pinned: true),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_children.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tap to edit · Hold and drag to reorder',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.crossAxisExtent / 180)
                        .floor()
                        .clamp(2, 4);
                    final tileWidth =
                        (constraints.crossAxisExtent - 12 * (columns - 1)) /
                        columns;
                    final extraTextHeight =
                        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
                          0,
                          double.infinity,
                        ) *
                        3;
                    final tileHeight = tileWidth + 64 + extraTextHeight;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: tileHeight,
                      ),
                      itemCount: _children.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _children.length) {
                          return Material(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _savingOrder || _linkingChild ? null : _addChild,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 32,
                                    color: colors.onPrimaryContainer,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Add child',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final child = _children[index];
                        final count = activeCounts[child.id] ?? 0;
                        return DragTarget<String>(
                          key: ValueKey('child-${child.id}'),
                          onWillAcceptWithDetails: (details) =>
                              !_savingOrder && details.data != child.id,
                          onAcceptWithDetails: (details) =>
                              _reorderChild(details.data, index),
                          builder: (context, candidates, rejected) =>
                              LongPressDraggable<String>(
                                data: child.id,
                                maxSimultaneousDrags:
                                    _savingOrder || _linkingChild ? 0 : 1,
                                onDragStarted: () {
                                  _autoScroller = EdgeDraggingAutoScroller(
                                    Scrollable.of(context),
                                    velocityScalar: 14,
                                  );
                                  setState(() => _draggingChildId = child.id);
                                },
                                onDragUpdate: (details) =>
                                    _autoScroller?.startAutoScrollIfNecessary(
                                      Rect.fromCenter(
                                        center: details.globalPosition,
                                        width: 1,
                                        height: 96,
                                      ),
                                    ),
                                onDragEnd: (_) {
                                  _autoScroller?.stopAutoScroll();
                                  if (mounted) {
                                    setState(() => _draggingChildId = null);
                                  }
                                },
                                feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(20),
                                  child: SizedBox(
                                    width: tileWidth,
                                    height: tileHeight,
                                    child: ChildProfileCard(
                                      child: child,
                                      activeGoalCount: count,
                                    ),
                                  ),
                                ),
                                child: Opacity(
                                  opacity: _draggingChildId == child.id
                                      ? 0.3
                                      : 1,
                                  child: ChildProfileCard(
                                    child: child,
                                    activeGoalCount: count,
                                    isDropTarget: candidates.isNotEmpty,
                                    onTap: _savingOrder
                                        ? null
                                        : () => _editChild(child: child),
                                  ),
                                ),
                              ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
