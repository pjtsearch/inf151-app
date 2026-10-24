import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../utils/goal_date_utils.dart';
import 'children_chips.dart';
import 'etsy_picker_dialog.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({
    super.key,
    required this.children,
    required this.onAddChild,
    this.initialChildId,
    this.goal,
    this.isCopy = false,
  });

  final List<Child> children;
  final Future<Child?> Function() onAddChild;
  final String? initialChildId;
  final Goal? goal;
  final bool isCopy;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _childFieldKey = GlobalKey<FormFieldState<String>>();
  late final List<Child> _children;
  String? _selectedChildId;
  bool _addingChild = false;
  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _durationController;
  late FrequencyUnit _frequencyUnit;
  late DurationUnit _durationUnit;
  late DateTime _startDate;
  EtsyProductReward? _etsyReward;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _children = List.of(widget.children);
    final initialChildId = widget.initialChildId ?? goal?.childId;
    _selectedChildId = _children.any((child) => child.id == initialChildId)
        ? initialChildId
        : _children.length == 1
        ? _children.single.id
        : null;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _etsyReward = goal?.reward is EtsyProductReward
        ? goal!.reward as EtsyProductReward
        : null;
    _rewardController = TextEditingController(
      text: _etsyReward?.title ?? (goal?.reward as FreeTextReward?)?.text ?? '',
    );
    _frequencyController = TextEditingController(
      text: '${goal?.frequency ?? 1}',
    );
    _durationController = TextEditingController(text: '${goal?.duration ?? 1}');
    _frequencyUnit = goal?.frequencyUnit ?? FrequencyUnit.day;
    _durationUnit = goal?.durationUnit ?? DurationUnit.week;
    _startDate = goal?.startDate ?? today();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final current = widget.goal;
    final now = DateTime.now();
    Navigator.pop(
      context,
      Goal(
        id: current?.id ?? now.microsecondsSinceEpoch.toString(),
        createdAt: widget.isCopy ? now : current?.createdAt ?? now,
        childId: _selectedChildId!,
        title: _titleController.text.trim(),
        frequency: int.parse(_frequencyController.text),
        frequencyUnit: _frequencyUnit,
        duration: int.parse(_durationController.text),
        durationUnit: _durationUnit,
        startDate: _startDate,
        reward: _etsyReward ?? FreeTextReward(_rewardController.text.trim()),
        completedTasks: current?.completedTasks ?? 0,
      ),
    );
  }

  Future<void> _addChild() async {
    setState(() => _addingChild = true);
    try {
      final child = await widget.onAddChild();
      if (child == null || !mounted) return;
      setState(() {
        _children.add(child);
        _selectedChildId = child.id;
        _childFieldKey.currentState!.didChange(child.id);
      });
    } finally {
      if (mounted) setState(() => _addingChild = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = formatDate(_startDate);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        top: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.goal == null || widget.isCopy
                        ? 'New goal'
                        : 'Edit goal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  FormField<String>(
                    key: _childFieldKey,
                    initialValue: _selectedChildId,
                    validator: (value) =>
                        _children.any((child) => child.id == value)
                        ? null
                        : 'Select a child for this goal',
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For child',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        ChildrenChips(
                          children: _children,
                          selectedChildId: _selectedChildId,
                          onSelected: (id) => setState(() {
                            _selectedChildId = id;
                            field.didChange(id);
                          }),
                          onAddChild: _addingChild ? null : _addChild,
                        ),
                        if (_children.isEmpty)
                          const Text('Add a child to create their first goal.'),
                        if (field.hasError)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Goal',
                      hintText: 'Take a 1 hour walk',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a goal'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rewardController,
                          readOnly: _etsyReward != null,
                          onChanged: (_) {
                            if (_etsyReward != null) {
                              setState(() => _etsyReward = null);
                            }
                          },
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: _etsyReward == null
                                ? 'Write-in reward'
                                : 'Etsy product',
                            hintText: 'A relaxing afternoon',
                            border: const OutlineInputBorder(),
                            suffixIcon: _etsyReward == null
                                ? null
                                : IconButton(
                                    tooltip: 'Remove Etsy product',
                                    onPressed: () => setState(() {
                                      _etsyReward = null;
                                      _rewardController.clear();
                                    }),
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 56),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () async {
                          final reward = await showDialog<EtsyProductReward>(
                            context: context,
                            builder: (_) => const EtsyPickerDialog(),
                          );
                          if (reward != null && mounted) {
                            setState(() {
                              _etsyReward = reward;
                              _rewardController.text = reward.title;
                            });
                          }
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Etsy Reward'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          controller: _frequencyController,
                          label: 'Times',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<FrequencyUnit>(
                          initialValue: _frequencyUnit,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(),
                          ),
                          items: FrequencyUnit.values
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text('per ${unit.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: (unit) {
                            if (unit != null) {
                              setState(() => _frequencyUnit = unit);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          controller: _durationController,
                          label: 'For',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<DurationUnit>(
                          initialValue: _durationUnit,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                            border: OutlineInputBorder(),
                          ),
                          items: DurationUnit.values
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.name),
                                ),
                              )
                              .toList(),
                          onChanged: (unit) {
                            if (unit != null) {
                              setState(() => _durationUnit = unit);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) setState(() => _startDate = date);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Starts $dateLabel'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      widget.goal == null || widget.isCopy
                          ? 'Save goal'
                          : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final number = int.tryParse(value ?? '');
      return number == null || number < 1 ? 'Use 1 or more' : null;
    },
  );
}
