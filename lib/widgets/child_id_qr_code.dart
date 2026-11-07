import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

class ChildIdQrCode extends StatelessWidget {
  const ChildIdQrCode({super.key, required this.childId, this.size = 220});

  final String childId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = QrCode(4, QrErrorCorrectLevel.M)..addData(childId);
    return Semantics(
      image: true,
      label: 'QR code containing child ID $childId',
      child: CustomPaint(
        size: Size.square(size),
        painter: _ChildIdQrPainter(QrImage(code)),
      ),
    );
  }
}

class _ChildIdQrPainter extends CustomPainter {
  const _ChildIdQrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    const quietZone = 4;
    final modules = image.moduleCount + quietZone * 2;
    final moduleSize = size.width / modules;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()..color = Colors.black;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (!image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (column + quietZone) * moduleSize,
            (row + quietZone) * moduleSize,
            moduleSize,
            moduleSize,
          ),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChildIdQrPainter oldDelegate) =>
      image != oldDelegate.image;
}
