// lib/models/detection.dart
import 'dart:ui';

class Detection {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double score;
  final int cls;

  const Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.score,
    required this.cls,
  });

  Rect toRect() => Rect.fromLTRB(x1, y1, x2, y2);
}

class CartonWithDefects {
  final Detection cartonBox;
  final List<Detection> defects;
  final String? qrText;
  final String status; // "ok" or "defect"

  const CartonWithDefects({
    required this.cartonBox,
    required this.defects,
    required this.qrText,
    required this.status,
  });
}

class PipelineResult {
  final List<CartonWithDefects> cartons;

  const PipelineResult({required this.cartons});

  bool get hasAnyDefect =>
      cartons.any((c) => c.status.toLowerCase() == 'defect');
}
