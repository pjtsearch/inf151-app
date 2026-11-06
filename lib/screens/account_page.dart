import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  Uint8List? _photo;
  bool _loading = true;
  bool _saving = false;

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
    if (!mounted) return;
    setState(() {
      _nameController.text = user?.displayName ?? '';
      _loading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
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
        final photoRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures/${user.uid}/profile.jpg');
        await photoRef.putData(
          photo,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await user.updatePhotoURL(await photoRef.getDownloadURL());
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
      appBar: AppBar(title: const Text('Account')),
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
