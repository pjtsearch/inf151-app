import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/goal.dart';
import '../services/gemini_punch_reader.dart';

class ScanCardPage extends StatefulWidget {
  const ScanCardPage({super.key, required this.goals});

  final List<Goal> goals;

  @override
  State<ScanCardPage> createState() => _ScanCardPageState();
}

class _ScanCardPageState extends State<ScanCardPage> {
  CameraController? _camera;
  final _barcodeScanner = BarcodeScanner(
    formats: const [BarcodeFormat.dataMatrix],
  );
  bool _loading = false;
  String? _frozenFramePath;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final cameraDescription =
          cameras
              .where(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              )
              .firstOrNull ??
          cameras.first;
      final camera = CameraController(
        cameraDescription,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (error) {
      if (mounted) setState(() => _cameraError = error.toString());
    }
  }

  Future<void> _scan() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _loading) return;
    setState(() => _loading = true);
    try {
      final image = await camera.takePicture();
      if (!mounted) return;
      setState(() => _frozenFramePath = image.path);
      final input = InputImage.fromFilePath(image.path);
      final barcodes = await _barcodeScanner.processImage(input);
      final value = barcodes
          .where((barcode) => barcode.format == BarcodeFormat.dataMatrix)
          .map((barcode) => barcode.rawValue)
          .whereType<String>()
          .firstOrNull;
      final card = value == null ? null : _parseCard(value);
      if (card == null) {
        await _showError('Invalid task card. Scan an active task card.');
        return;
      }

      final goal = widget.goals
          .where((item) => item.id == card.goalId)
          .firstOrNull;
      if (goal == null ||
          goal.isPastOn(DateTime.now()) ||
          card.start < 0 ||
          card.end < card.start ||
          card.end >= goal.totalTasks) {
        await _showError('Invalid task card. Scan an active task card.');
        return;
      }
      if (card.start != goal.completedTasks) {
        await _showError('Prior tasks not completed yet');
        return;
      }

      final count = await readPunchCount(image.path);
      if (!mounted) return;
      if (count != card.end - card.start + 1) {
        await _showError(
          'Task card not completed. Scan again once it\'s completed.',
        );
        return;
      }
      Navigator.of(context).pop(goal.copyWith(completedTasks: card.end + 1));
    } catch (error) {
      if (!mounted) return;
      print(error);
      await _showError('Could not scan this card. Please try again.');
    }
  }

  _TaskCardData? _parseCard(String value) {
    final fields = value.split('\t');
    if (fields.length != 3 || fields[0].isEmpty) return null;
    final start = int.tryParse(fields[1]);
    final end = int.tryParse(fields[2]);
    if (start == null || end == null) return null;
    return _TaskCardData(fields[0], start, end);
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _frozenFramePath = null;
      });
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Scan task card')),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_cameraError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Unable to start camera: $_cameraError'),
                  ),
                )
              else if (camera == null || !camera.value.isInitialized)
                const Center(child: CircularProgressIndicator())
              else if (_frozenFramePath != null)
                Image.file(
                  File(_frozenFramePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      CameraPreview(camera),
                )
              else
                CameraPreview(camera),
              if (camera?.value.isInitialized == true && !_loading)
                const Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Text(
                    'Center the card’s data matrix in the camera view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                ),
              if (!_loading && _cameraError == null)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 32,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: camera?.value.isInitialized == true
                          ? _scan
                          : null,
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Scan'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_loading)
          const ColoredBox(
            color: Color(0x99000000),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _TaskCardData {
  const _TaskCardData(this.goalId, this.start, this.end);

  final String goalId;
  final int start;
  final int end;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
