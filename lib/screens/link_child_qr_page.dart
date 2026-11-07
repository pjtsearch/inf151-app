import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class LinkChildQrPage extends StatefulWidget {
  const LinkChildQrPage({super.key, this.title = 'Link a child'});

  final String title;

  @override
  State<LinkChildQrPage> createState() => _LinkChildQrPageState();
}

class _LinkChildQrPageState extends State<LinkChildQrPage> {
  CameraController? _camera;
  final _zxing = Zxing();
  bool _scanning = false;
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
              .where((camera) => camera.lensDirection == CameraLensDirection.back)
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
    if (camera == null || !camera.value.isInitialized || _scanning) return;
    setState(() => _scanning = true);
    try {
      final image = await camera.takePicture();
      final result = await _zxing.readBarcodesImagePath(
        image,
        DecodeParams(
          format: Format.qrCode,
          tryHarder: true,
          maxSize: 4096,
        ),
      );
      final childId = result.codes
          .where((code) => code.isValid)
          .map((code) => code.text?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      if (childId == null) {
        await _showMessage('Could not read a child QR code. Try again.');
      } else if (mounted) {
        Navigator.of(context).pop(childId);
      }
    } catch (_) {
      await _showMessage('Could not scan the QR code. Please try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
          else
            CameraPreview(camera),
          if (camera?.value.isInitialized == true && !_scanning)
            const Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Text(
                'Center the child’s QR code in the camera view.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
          if (!_scanning && _cameraError == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: camera?.value.isInitialized == true ? _scan : null,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  ),
                ),
              ),
            ),
          if (_scanning)
            const ColoredBox(
              color: Color(0x99000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
