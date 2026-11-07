import 'package:flutter/material.dart';

import '../services/child_session_storage.dart';
import 'link_child_qr_page.dart';

class ChildQrEntryPage extends StatefulWidget {
  const ChildQrEntryPage({
    super.key,
    required this.onActivated,
    required this.onExit,
  });

  final ValueChanged<String> onActivated;
  final Future<void> Function() onExit;

  @override
  State<ChildQrEntryPage> createState() => _ChildQrEntryPageState();
}

class _ChildQrEntryPageState extends State<ChildQrEntryPage> {
  final _sessions = ChildSessionStorage();
  bool _scanning = false;

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final childId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const LinkChildQrPage(title: 'Scan child QR code'),
        ),
      );
      if (childId == null || !mounted) return;
      await _sessions.activate(childId);
      if (mounted) widget.onActivated(childId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to these goals. Try scanning again.')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to your goals'),
        actions: [
          TextButton(onPressed: widget.onExit, child: const Text('Parent sign-in')),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 88,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Scan your child QR code',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask a parent to open your profile and show your QR code.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(_scanning ? 'Connecting…' : 'Scan QR code'),
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
}
