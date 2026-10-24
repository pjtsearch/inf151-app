import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../models/goal_sort.dart';
import 'child_form_page.dart';
import 'manage_children_page.dart';
import 'scan_card_page.dart';
import '../services/child_storage.dart';
import '../services/goal_storage.dart';
import '../services/punch_card_pdf.dart';
import '../utils/goal_date_utils.dart';
import '../widgets/empty_goals.dart';
import '../widgets/children_chips.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_sheet.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage>
    with SingleTickerProviderStateMixin {
  final _storage = GoalStorage();
  final _childStorage = ChildStorage();
  final List<Child> _children = [];
  final List<Goal> _goals = [];
  String? _selectedChildId;
  bool _showPast = false;
  bool _loading = true;
  GoalSort _sort = const GoalSort();
  bool _savingSort = false;
  Timer? _refreshTimer;
  late final TabController _statusController;

  @override
  void initState() {
    super.initState();
    _statusController = TabController(length: 2, vsync: this);
    _loadGoals();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final savedChildren = await _childStorage.load();
    final savedGoals = await _storage.load();
    final savedSort = await _storage.loadSort();
    if (!mounted) return;
    setState(() {
      _sort = savedSort;
      _children
        ..clear()
        ..addAll(savedChildren);
      _goals
        ..clear()
        ..addAll(savedGoals);
      _loading = false;
    });
  }

  Future<void> _setSort(GoalSort sort) async {
    final previous = _sort;
    setState(() {
      _sort = sort;
      _savingSort = true;
    });
    try {
      await _storage.saveSort(sort);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sort = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save sorting preference. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingSort = false);
    }
  }

  Future<void> _saveChild(Child child) async {
    final children = List.of(_children);
    final index = children.indexWhere((item) => item.id == child.id);
    if (index < 0) {
      children.add(child);
    } else {
      children[index] = child;
    }
    await _saveChildren(children);
  }

  Future<void> _saveChildren(List<Child> children) async {
    await _childStorage.save(children);
    if (!mounted) return;
    setState(() {
      _children
        ..clear()
        ..addAll(children);
    });
  }

  Future<Child?> _createChild() => Navigator.of(context).push<Child>(
    MaterialPageRoute(builder: (_) => ChildFormPage(onSave: _saveChild)),
  );

  Future<void> _manageChildren() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ManageChildrenPage(
        children: _children,
        goals: _goals,
        onSave: _saveChild,
        onReorder: _saveChildren,
      ),
    ),
  );

  Future<void> _addChild() async {
    final child = await _createChild();
    if (child != null && mounted) {
      setState(() => _selectedChildId = child.id);
    }
  }

  Future<void> _saveGoals() async {
    await _storage.save(_goals);
    if (mounted) setState(() {});
  }

  Future<void> _editGoal({Goal? goal, bool isCopy = false}) async {
    final result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalFormSheet(
        goal: goal,
        isCopy: isCopy,
        children: _children,
        initialChildId: _selectedChildId ?? goal?.childId,
        onAddChild: _createChild,
      ),
    );
    if (result == null || !mounted) return;

    _statusController.animateTo(0);
    setState(() {
      _showPast = false;
      if (_selectedChildId != null) _selectedChildId = result.childId;
      final index = _goals.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        _goals.add(result);
      } else {
        _goals[index] = result;
      }
    });
    await _saveGoals();
  }

  Future<void> _copyGoal(Goal goal) async {
    final copy = goal.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startDate: today(),
      completedTasks: 0,
    );
    await _editGoal(goal: copy, isCopy: true);
  }

  Future<bool> _confirmDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text('“${goal.title}” will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteGoal(Goal goal) async {
    if (!await _confirmDeleteGoal(goal) || !mounted) return;
    await _removeGoal(goal);
  }

  Future<void> _removeGoal(Goal goal) async {
    if (!mounted) return;
    setState(() => _goals.removeWhere((item) => item.id == goal.id));
    await _saveGoals();
  }

  Future<void> _printPunchCard(Goal goal) async {
    final child = _children
        .where((child) => child.id == goal.childId)
        .firstOrNull;
    final pdf = await buildPunchCardPdf(goal, childName: child?.name);
    await Printing.layoutPdf(
      onLayout: (_) => pdf,
      name:
          '${goal.title.replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_')}_punch_card.pdf',
    );
  }

  Future<void> _scanCard() async {
    final updatedGoal = await Navigator.of(context).push<Goal>(
      MaterialPageRoute(builder: (_) => ScanCardPage(goals: List.of(_goals))),
    );
    if (updatedGoal == null || !mounted) return;
    final index = _goals.indexWhere((goal) => goal.id == updatedGoal.id);
    if (index < 0) return;
    setState(() => _goals[index] = updatedGoal);
    await _saveGoals();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final goals =
        _goals
            .where(
              (goal) =>
                  goal.isPastOn(now) == _showPast &&
                  (_selectedChildId == null ||
                      goal.childId == _selectedChildId),
            )
            .toList()
          ..sort(_sort.compare);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('Goals'),
                pinned: true,
                actions: [
                  IconButton(
                    tooltip: 'Manage children',
                    onPressed: _loading ? null : _manageChildren,
                    icon: const Icon(Icons.people_outline),
                  ),
                  PopupMenuButton<GoalSort>(
                    tooltip: 'Sort goals',
                    enabled: !_loading && !_savingSort,
                    icon: const Icon(Icons.sort),
                    onSelected: _setSort,
                    itemBuilder: (_) => [
                      for (final by in GoalSortBy.values)
                        CheckedPopupMenuItem(
                          value: GoalSort(by: by, descending: _sort.descending),
                          checked: _sort.by == by,
                          child: Text(by.label),
                        ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: GoalSort(by: _sort.by),
                        checked: !_sort.descending,
                        child: Text(
                          'Ascending · ${_sort.ascendingDescription}',
                        ),
                      ),
                      CheckedPopupMenuItem(
                        value: GoalSort(by: _sort.by, descending: true),
                        checked: _sort.descending,
                        child: Text(
                          'Descending · ${_sort.descendingDescription}',
                        ),
                      ),
                    ],
                  ),
                ],
                bottom: _loading
                    ? null
                    : PreferredSize(
                        preferredSize: const Size.fromHeight(108),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChildrenChips(
                              children: _children,
                              selectedChildId: _selectedChildId,
                              showAllChildren: true,
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              onSelected: (id) =>
                                  setState(() => _selectedChildId = id),
                              onAddChild: _addChild,
                            ),
                            TabBar(
                              controller: _statusController,
                              isScrollable: false,
                              tabAlignment: TabAlignment.fill,
                              dividerHeight: 0,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorWeight: 2,
                              labelColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              indicatorColor: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              unselectedLabelColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              labelStyle: Theme.of(
                                context,
                              ).textTheme.titleSmall,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              tabs: const [
                                Tab(text: 'Active'),
                                Tab(text: 'Past'),
                              ],
                              onTap: (index) {
                                setState(() => _showPast = index == 1);
                              },
                            ),
                          ],
                        ),
                      ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (goals.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 184),
                    child: EmptyGoals(isPast: _showPast),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 184),
                  sliver: SliverList.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return Dismissible(
                        key: ValueKey(goal.id),
                        direction: DismissDirection.endToStart,
                        background: const _GoalDeleteBackground(),
                        confirmDismiss: (_) => _confirmDeleteGoal(goal),
                        onDismissed: (_) => _removeGoal(goal),
                        child: GoalCard(
                          goal: goal,
                          child: _children
                              .where((child) => child.id == goal.childId)
                              .firstOrNull,
                          isPast: _showPast,
                          onCopy: () => _copyGoal(goal),
                          onDelete: () => _deleteGoal(goal),
                          onPrint: () => _printPunchCard(goal),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          if (!_loading) const _BottomSurfaceGradient(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                  ),
                  onPressed: _loading ? null : _scanCard,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan card'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _editGoal(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add goal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalDeleteBackground extends StatelessWidget {
  const _GoalDeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Text('Delete', style: TextStyle(color: colors.onErrorContainer)),
        ],
      ),
    );
  }
}

class _BottomSurfaceGradient extends StatelessWidget {
  const _BottomSurfaceGradient();

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: 200,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
      ),
    ),
  );
}
