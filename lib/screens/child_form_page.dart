import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/child.dart';
import '../models/child_color.dart';
import '../utils/firestore_photo.dart';
import '../widgets/child_avatar.dart';
import '../widgets/child_id_qr_code.dart';

class ChildFormPage extends StatefulWidget {
  const ChildFormPage({super.key, required this.onSave, this.onDelete, this.child});

  final Future<void> Function(Child child) onSave;
  final Future<bool> Function(Child child)? onDelete;
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
  bool _deleting = false;

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
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
        requestFullMetadata: false,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > maxFirestorePhotoBytes) {
        throw const FormatException(
          'Please choose a photo smaller than 650 KB.',
        );
      }
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

  Future<void> _delete() async {
    final child = widget.child;
    final onDelete = widget.onDelete;
    if (child == null || onDelete == null || _saving || _deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${child.name}?'),
        content: const Text(
          'This removes the child from your account. If you are the only parent, the child and your tasks for them will be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final childDeleted = await onDelete(child);
      if (mounted) {
        Navigator.pop(
          context,
          childDeleted ? const Child(id: '', name: '') : child,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete child. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_deleting,
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
                  if (widget.child != null) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Child QR code',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Share this QR code to give access to this child.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Center(child: ChildIdQrCode(childId: widget.child!.id)),
                    const SizedBox(height: 8),
                    SelectableText(
                      widget.child!.id,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],
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
                  if (widget.child != null && widget.onDelete != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving || _deleting || _pickingPhoto ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(_deleting ? 'Deleting…' : 'Delete child'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
