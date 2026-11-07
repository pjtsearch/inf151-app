import 'package:flutter/material.dart';

import '../models/child.dart';
import '../models/goal.dart';
import '../models/reminder_settings.dart';
import '../services/goal_reminder_service.dart';
import '../widgets/reminder_settings_editor.dart';

class ChildSettingsPage extends StatefulWidget {
  const ChildSettingsPage({
    super.key,
    required this.childName,
    required this.reminderService,
    required this.goals,
    required this.child,
    required this.onSignOut,
  });

  final String childName;
  final GoalReminderService reminderService;
  final List<Goal> goals;
  final Child child;
  final Future<void> Function() onSignOut;

  @override
  State<ChildSettingsPage> createState() => _ChildSettingsPageState();
}

class _ChildSettingsPageState extends State<ChildSettingsPage> {
  ReminderSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final settings = await widget.reminderService.loadSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _save(ReminderSettings settings) async {
    setState(() {
      _settings = settings;
      _saving = true;
    });
    try {
      await widget.reminderService.saveSettings(settings);
      await widget.reminderService.sync(widget.goals, [widget.child]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save reminder settings. Please try again.')),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await widget.onSignOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${widget.childName}’s reminders',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (_settings case final settings?)
                ReminderSettingsEditor(
                  value: settings,
                  service: widget.reminderService,
                  enabled: !_loading && !_saving,
                  onChanged: _save,
                )
              else if (_failed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Could not load reminders. Try again.'),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
