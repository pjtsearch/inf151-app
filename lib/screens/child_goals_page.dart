import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../models/goal_sort.dart';
import '../services/child_session_storage.dart';
import '../services/goal_reminder_service.dart';
import '../services/goal_storage.dart';
import '../widgets/child_avatar.dart';
import '../widgets/empty_goals.dart';
import '../widgets/goal_card.dart';
import 'child_settings_page.dart';

class ChildGoalsPage extends StatefulWidget {
  const ChildGoalsPage({
    super.key,
    required this.childId,
    required this.onSignOut,
    this.reminderService,
  });

  final String childId;
  final Future<void> Function() onSignOut;
  final GoalReminderService? reminderService;

  @override
  State<ChildGoalsPage> createState() => _ChildGoalsPageState();
}

class _ChildGoalsPageState extends State<ChildGoalsPage>
    with SingleTickerProviderStateMixin {
  final _sessions = ChildSessionStorage();
  final _goalStorage = GoalStorage();
  late final GoalReminderService _reminders =
      widget.reminderService ?? GoalReminderService();
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final List<Goal> _goals = [];
  Child? _child;
  GoalSort _sort = const GoalSort();
  bool _loading = true;
  bool _loadFailed = false;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final values = await Future.wait<Object?>([
        _sessions.loadChild(widget.childId),
        _goalStorage.loadForChild(widget.childId),
      ]);
      final child = values[0] as Child?;
      final goals = values[1] as List<Goal>;
      if (child == null) throw StateError('Child profile was not found.');
      if (!mounted) return;
      setState(() {
        _child = child;
        _goals
          ..clear()
          ..addAll(goals);
        _loading = false;
      });
      try {
        await _reminders.sync(goals, [child]);
      } catch (_) {
        // Reminder scheduling must not prevent access to the goals.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openSettings() async {
    final child = _child;
    if (child == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChildSettingsPage(
          childName: child.name,
          reminderService: _reminders,
          goals: List.of(_goals),
          child: child,
          onSignOut: widget.onSignOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentParentId = FirebaseAuth.instance.currentUser?.uid;
    final goals = _goals
        .where((goal) => goal.isPastOn(now) == _showPast)
        .toList()
      ..sort((a, b) => _sort.compare(a, b, currentParentId: currentParentId));
    final child = _child;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.large(
            pinned: true,
            title: child == null
                ? const Text('Your goals')
                : Row(
                    children: [
                      ChildAvatar(child: child, radius: 18),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${child.name}’s goals',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
            actions: [
              PopupMenuButton<GoalSort>(
                tooltip: 'Sort goals',
                icon: const Icon(Icons.sort),
                onSelected: (sort) => setState(() => _sort = sort),
                itemBuilder: (_) => [
                  for (final by in GoalSortBy.values.where(
                    (value) => value != GoalSortBy.createdByMe,
                  ))
                    CheckedPopupMenuItem(
                      value: GoalSort(by: by, descending: _sort.descending),
                      checked: _sort.by == by,
                      child: Text(by.label),
                    ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem(
                    value: GoalSort(by: _sort.by),
                    checked: !_sort.descending,
                    child: Text('Ascending · ${_sort.ascendingDescription}'),
                  ),
                  CheckedPopupMenuItem(
                    value: GoalSort(by: _sort.by, descending: true),
                    checked: _sort.descending,
                    child: Text('Descending · ${_sort.descendingDescription}'),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: _loading ? null : _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
              onTap: (index) => setState(() => _showPast = index == 1),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadFailed)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load your goals.'),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              else if (goals.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyGoals(
                    isPast: _showPast,
                    activeMessage: 'Ask a parent to add a goal.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: goals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => GoalCard(
                      goal: goals[index],
                      isCreatedByMe:
                          goals[index].creatorId == currentParentId,
                      child: child,
                      isPast: _showPast,
                      readOnly: true,
                      onCopy: () {},
                      onDelete: () {},
                      onPrint: () {},
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
