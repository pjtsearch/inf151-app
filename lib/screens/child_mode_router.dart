import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/child_session_storage.dart';
import '../services/goal_reminder_service.dart';
import 'child_goals_page.dart';
import 'child_qr_entry_page.dart';

class ChildModeRouter extends StatefulWidget {
  const ChildModeRouter({super.key, this.reminderService});

  final GoalReminderService? reminderService;

  @override
  State<ChildModeRouter> createState() => _ChildModeRouterState();
}

class _ChildModeRouterState extends State<ChildModeRouter> {
  final _sessions = ChildSessionStorage();
  String? _childId;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final childId = await _sessions.loadChildId();
      if (!mounted) return;
      setState(() {
        _childId = childId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.isAnonymous == true) {
        await _sessions.clear();
      }
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not exit child access. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Child access')),
        body: Center(
          child: TextButton(onPressed: _loadSession, child: const Text('Try again')),
        ),
      );
    }
    final childId = _childId;
    if (childId == null) {
      return ChildQrEntryPage(
        onActivated: (id) => setState(() => _childId = id),
        onExit: _signOut,
      );
    }
    return ChildGoalsPage(
      key: ValueKey(childId),
      childId: childId,
      onSignOut: _signOut,
      reminderService: widget.reminderService,
    );
  }
}
