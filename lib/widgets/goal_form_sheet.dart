import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/goal.dart';
import '../utils/goal_date_utils.dart';

class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.goal, this.isCopy = false});

  final Goal? goal;
  final bool isCopy;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _durationController;
  late FrequencyUnit _frequencyUnit;
  late DurationUnit _durationUnit;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _rewardController = TextEditingController(text: goal?.reward ?? '');
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
    Navigator.pop(
      context,
      Goal(
        id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        frequency: int.parse(_frequencyController.text),
        frequencyUnit: _frequencyUnit,
        duration: int.parse(_durationController.text),
        durationUnit: _durationUnit,
        startDate: _startDate,
        reward: _rewardController.text.trim(),
        isCompleted: current?.isCompleted ?? false,
      ),
    );
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
                  TextFormField(
                    controller: _rewardController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Reward',
                      hintText: 'A relaxing afternoon',
                      border: OutlineInputBorder(),
                    ),
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
