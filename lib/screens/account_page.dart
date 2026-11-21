import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/firestore_photo.dart';
import '../models/reminder_settings.dart';
import '../services/goal_reminder_service.dart';
import '../widgets/reminder_settings_editor.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.reminderService,
    required this.onRemindersChanged,
  });

  final GoalReminderService reminderService;
  final Future<void> Function() onRemindersChanged;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  Uint8List? _photo;
  ReminderSettings? _reminderSettings;
  bool _loading = true;
  bool _saving = false;
  bool _savingReminders = false;
  bool _reminderLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    final data = user == null
        ? null
        : (await FirebaseFirestore.instance
                  .collection('parents')
                  .doc(user.uid)
                  .get())
              .data();
    final encodedPhoto = data?['photoData'] as String?;
    if (!mounted) return;
    setState(() {
      _nameController.text = user?.displayName ?? '';
      _photo = encodedPhoto == null ? null : base64Decode(encodedPhoto);
      _loading = false;
    });
    try {
      final settings = await widget.reminderService.loadSettings();
      if (mounted) setState(() => _reminderSettings = settings);
    } catch (_) {
      if (mounted) setState(() => _reminderLoadFailed = true);
    }
  }

  Future<void> _loadReminderSettings() async {
    setState(() => _reminderLoadFailed = false);
    try {
      final settings = await widget.reminderService.loadSettings();
      if (mounted) setState(() => _reminderSettings = settings);
    } catch (_) {
      if (mounted) setState(() => _reminderLoadFailed = true);
    }
  }

  Future<void> _saveReminderSettings(ReminderSettings settings) async {
    if (_savingReminders) return;
    final previous = _reminderSettings;
    setState(() {
      _reminderSettings = settings;
      _savingReminders = true;
    });
    try {
      await widget.reminderService.saveSettings(settings);
      await widget.onRemindersChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _reminderSettings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save reminder settings. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingReminders = false);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 70,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > maxFirestorePhotoBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a photo smaller than 650 KB.')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw StateError('No signed-in account.');

      await user.updateDisplayName(_nameController.text.trim());
      final photo = _photo;
      if (photo != null) {
        await FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .set({'photoData': base64Encode(photo)}, SetOptions(merge: true));
      }
      await user.reload();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save account changes. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilePhotoUrl = _auth.currentUser?.photoURL;
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Settings')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 58,
                              backgroundImage: _photo != null
                                  ? MemoryImage(_photo!)
                                  : profilePhotoUrl != null
                                  ? NetworkImage(profilePhotoUrl)
                                  : null,
                              child: _photo == null && profilePhotoUrl == null
                                  ? const Icon(Icons.person_outline, size: 56)
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton.filled(
                                tooltip: 'Choose profile picture',
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.camera_alt_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save changes'),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Reminders', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (_reminderSettings case final settings?)
                        ReminderSettingsEditor(
                          value: settings,
                          service: widget.reminderService,
                          enabled: !_savingReminders && !_saving,
                          onChanged: _saveReminderSettings,
                        )
                      else if (_reminderLoadFailed)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _loadReminderSettings,
                            child: const Text('Could not load reminder settings. Try again'),
                          ),
                        )
                      else
                        const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text('Sign-in account', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(FirebaseAuth.instance.currentUser?.email ?? ''),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) Navigator.of(context).pop();
                        },
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
}
