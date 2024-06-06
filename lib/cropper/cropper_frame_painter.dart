import 'package:flutter/material.dart';

class CropperFramePainter extends CustomPainter {
  final double squareDimension;

  const CropperFramePainter({required this.squareDimension});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: squareDimension,
            height: squareDimension,
          ),
          const Radius.circular(16),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    final borderPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: squareDimension,
            height: squareDimension,
          ),
          const Radius.circular(16),
        ),
      )
      ..fillType = PathFillType.nonZero;

    canvas
      ..drawPath(path, paint)
      ..drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
