// lib/painters/annotation_painter.dart
import 'package:flutter/material.dart';

import '../models/detection.dart';

class AnnotationPainter extends CustomPainter {
  final List<CartonWithDefects> cartons;
  final double imageWidth;
  final double imageHeight;

  AnnotationPainter({
    required this.cartons,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cartons.isEmpty) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    final cartonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final defectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.redAccent;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final carton in cartons) {
      final cb = carton.cartonBox;

      final left = cb.x1 * scaleX;
      final top = cb.y1 * scaleY;
      final right = cb.x2 * scaleX;
      final bottom = cb.y2 * scaleY;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(rect, cartonPaint);

      final label =
          'carton [${carton.status}] ${(cb.score * 100).toStringAsFixed(1)}%'
          '${carton.qrText != null ? ' | QR: ${carton.qrText}' : ''}';

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 12,
          backgroundColor: Colors.black54,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(left, top - textPainter.height - 2));

      for (final d in carton.defects) {
        final dl = d.x1 * scaleX;
        final dt = d.y1 * scaleY;
        final dr = d.x2 * scaleX;
        final db = d.y2 * scaleY;

        final dRect = Rect.fromLTRB(dl, dt, dr, db);
        canvas.drawRect(dRect, defectPaint);

        final dLabel =
            'defect ${(d.score * 100).toStringAsFixed(1)}%';
        textPainter.text = TextSpan(
          text: dLabel,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 10,
            backgroundColor: Colors.black54,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(dl, dt - textPainter.height - 1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) {
    return oldDelegate.cartons != cartons ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight;
  }
}
