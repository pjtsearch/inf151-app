import 'dart:async';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/goal.dart';
import 'scan_card_page.dart';
import '../services/goal_storage.dart';
import '../services/punch_card_pdf.dart';
import '../utils/goal_date_utils.dart';
import '../widgets/empty_goals.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_sheet.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final _storage = GoalStorage();
  final List<Goal> _goals = [];
  bool _showPast = false;
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final savedGoals = await _storage.load();
    if (!mounted) return;
    setState(() {
      _goals
        ..clear()
        ..addAll(savedGoals);
      _loading = false;
    });
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
      builder: (_) => GoalFormSheet(goal: goal, isCopy: isCopy),
    );
    if (result == null) return;

    setState(() {
      _showPast = false;
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

  Future<void> _deleteGoal(Goal goal) async {
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
    if (confirmed != true) return;
    setState(() => _goals.removeWhere((item) => item.id == goal.id));
    await _saveGoals();
  }

  Future<void> _printPunchCard(Goal goal) async {
    final pdf = await buildPunchCardPdf(goal);
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
        _goals.where((goal) => goal.isPastOn(now) == _showPast).toList()
          ..sort((a, b) => a.endDate.compareTo(b.endDate));

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Active')),
                      ButtonSegment(value: true, label: Text('Past')),
                    ],
                    selected: {_showPast},
                    onSelectionChanged: (selection) {
                      setState(() => _showPast = selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: goals.isEmpty
                      ? EmptyGoals(isPast: _showPast)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: goals.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => GoalCard(
                            goal: goals[index],
                            isPast: _showPast,
                            onCopy: () => _copyGoal(goals[index]),
                            onDelete: () => _deleteGoal(goals[index]),
                            onPrint: () => _printPunchCard(goals[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan-card',
            onPressed: _scanCard,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan card'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add-goal',
            onPressed: () => _editGoal(),
            icon: const Icon(Icons.add),
            label: const Text('Add goal'),
          ),
        ],
      ),
    );
  }
}
