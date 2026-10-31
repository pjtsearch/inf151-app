import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child.dart';
import '../models/child_color.dart';
import '../widgets/child_avatar.dart';

class ChildFormPage extends StatefulWidget {
  const ChildFormPage({super.key, required this.onSave, this.child});

  final Future<void> Function(Child child) onSave;
  final Child? child;

  @override
  State<ChildFormPage> createState() => _ChildFormPageState();
}

class _ChildFormPageState extends State<ChildFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  Uint8List? _photoBytes;
  late ChildColor _color;
  bool _pickingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.name ?? '');
    _photoBytes = widget.child?.photoBytes;
    _color = widget.child?.color ?? ChildColor.blue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (photo == null) return;
      if (await photo.length() > 2 * 1024 * 1024) {
        throw const FormatException('Please choose a photo smaller than 2 MB.');
      }
      final bytes = await photo.readAsBytes();
      if (mounted) setState(() => _photoBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'Could not open the photo. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingPhoto) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final child = Child(
      id: widget.child?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      photoBytes: _photoBytes,
      color: _color,
    );
    try {
      await widget.onSave(child);
      if (mounted) Navigator.pop(context, child);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save child. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.child == null ? 'Add child' : 'Edit child'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ChildAvatar(
                      child: Child(
                        id: 'preview',
                        name: _nameController.text.trim(),
                        photoBytes: _photoBytes,
                        color: _color,
                      ),
                      radius: 48,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving || _pickingPhoto ? null : _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _pickingPhoto
                            ? 'Opening photos…'
                            : _photoBytes == null
                            ? 'Add photo (optional)'
                            : 'Change photo',
                      ),
                    ),
                  ),
                  if (_photoBytes != null)
                    Center(
                      child: TextButton(
                        onPressed: _saving || _pickingPhoto
                            ? null
                            : () => setState(() => _photoBytes = null),
                        child: const Text('Remove photo'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Child’s name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name'
                        : null,
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) {
                      if (!_saving && !_pickingPhoto) _save();
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      for (final color in ChildColor.values)
                        Expanded(
                          child: Semantics(
                            label: color.label,
                            button: true,
                            selected: _color == color,
                            enabled: !_saving,
                            child: Tooltip(
                              message: color.label,
                              excludeFromSemantics: true,
                              child: InkResponse(
                                onTap: _saving
                                    ? null
                                    : () => setState(() => _color = color),
                                radius: 24,
                                child: SizedBox(
                                  height: 48,
                                  child: Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: color.background,
                                        shape: BoxShape.circle,
                                      ),
                                      child: _color == color
                                          ? Icon(
                                              Icons.check,
                                              size: 20,
                                              color: color.foreground,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving || _pickingPhoto ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : widget.child == null
                          ? 'Save child'
                          : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
