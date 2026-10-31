import 'package:flutter/material.dart';

import '../models/reminder_settings.dart';
import '../services/goal_reminder_service.dart';

class ReminderSettingsEditor extends StatefulWidget {
  const ReminderSettingsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.service,
    this.enabled = true,
  });

  final ReminderSettings value;
  final ValueChanged<ReminderSettings> onChanged;
  final GoalReminderService service;
  final bool enabled;

  @override
  State<ReminderSettingsEditor> createState() => _ReminderSettingsEditorState();
}

class _ReminderSettingsEditorState extends State<ReminderSettingsEditor> {
  bool _requesting = false;

  Future<void> _toggle(bool enabled) async {
    if (!enabled) {
      widget.onChanged(widget.value.copyWith(enabled: false));
      return;
    }
    setState(() => _requesting = true);
    try {
      final allowed = await widget.service.requestPermission();
      if (!mounted) return;
      if (allowed) {
        widget.onChanged(widget.value.copyWith(enabled: true));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications in your device settings to enable reminders.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not enable reminders. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = widget.value;
    final time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Goal reminders'),
          subtitle: Text(
            widget.service.isSupported
                ? 'Notify me only when recorded check-ins are behind.'
                : 'Reminders are available in the Android and iOS apps.',
          ),
          value: reminder.enabled,
          onChanged:
              _requesting || !widget.enabled || !widget.service.isSupported
              ? null
              : _toggle,
        ),
        if (reminder.enabled) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            trailing: Text(time.format(context)),
            onTap: _requesting || !widget.enabled || !widget.service.isSupported
                ? null
                : () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (selected != null && mounted) {
                      widget.onChanged(
                        reminder.copyWith(
                          hour: selected.hour,
                          minute: selected.minute,
                        ),
                      );
                    }
                  },
          ),
          const Text(
            'This time applies to all goals. Each goal follows its own daily, weekly or monthly schedule.',
          ),
        ],
      ],
    );
  }
}
