import 'package:flutter/material.dart';

import '../models/reminder_settings.dart';
import '../services/goal_reminder_service.dart';
import '../widgets/reminder_settings_editor.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.reminderService,
    required this.onRemindersChanged,
  });

  final GoalReminderService reminderService;
  final Future<void> Function() onRemindersChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReminderSettings? _settings;
  bool _loadFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final settings = await widget.reminderService.loadSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(ReminderSettings settings) async {
    if (_saving) return;
    final previous = _settings;
    setState(() {
      _settings = settings;
      _saving = true;
    });
    try {
      await widget.reminderService.saveSettings(settings);
    } catch (_) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save reminder settings. Please try again.'),
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    await widget.onRemindersChanged();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: settings == null
            ? Center(
                child: _loadFailed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load settings.'),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Reminders',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ReminderSettingsEditor(
                        value: settings,
                        service: widget.reminderService,
                        enabled: !_saving,
                        onChanged: _save,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
