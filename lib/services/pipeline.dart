// lib/services/pipeline.dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:qr_code_vision/qr_code_vision.dart';

import '../config.dart';
import '../models/detection.dart';
import 'api_client.dart';
import 'carton_detector.dart';
import 'defect_detector.dart';
import 'tracker.dart';

class RectInt {
  final int left;
  final int top;
  final int width;
  final int height;

  RectInt({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  int get right => left + width;
  int get bottom => top + height;
}

class CartonPipeline {
  final CartonDetector cartonDetector;
  final DefectDetector defectDetector;
  final Tracker tracker;
  final ApiClient apiClient;

  CartonPipeline({
    required this.cartonDetector,
    required this.defectDetector,
    required this.tracker,
    required this.apiClient,
  });

  /// ده زي process_frame في main.py لكن على Image واحدة
  Future<PipelineResult> runOnImageBytes(
    Uint8List bytes, {
    required int frameIndex,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Cannot decode image');
    }

    final origW = decoded.width;
    final origH = decoded.height;

    // 1) detect cartons
    final cartons = await cartonDetector.detectCartons(decoded);

    final List<CartonWithDefects> cartonResults = [];

    for (final carton in cartons) {
      // expand box
      final expandedRect = _expandBox(
        carton,
        origW: origW,
        origH: origH,
        expandRatio: AppConfig.expandRatio,
      );

      if (expandedRect.width <= 0 || expandedRect.height <= 0) continue;

      // crop
      final crop = img.copyCrop(
        decoded,
        x: expandedRect.left,
        y: expandedRect.top,
        width: expandedRect.width,
        height: expandedRect.height,
      );

      // 2) defect detection على الكروب
      final defectLocal = await defectDetector.detectDefects(crop);

      final defectGlobal = defectLocal
          .map(
            (d) => Detection(
              x1: d.x1 + expandedRect.left,
              y1: d.y1 + expandedRect.top,
              x2: d.x2 + expandedRect.left,
              y2: d.y2 + expandedRect.top,
              score: d.score,
              cls: d.cls,
            ),
          )
          .toList();

      final defectCount = defectGlobal.length;
      final statusNow = defectCount > 0 ? 'defect' : 'ok';

      // 3) QR من الكروب
      final qrText = await _readQrFromCrop(crop);

      String finalStatus = statusNow;
      if (qrText != null && qrText.isNotEmpty) {
        final boxList =
            [carton.x1, carton.y1, carton.x2, carton.y2];

        if (!tracker.tracks.containsKey(qrText)) {
          tracker.createNewTrack(
            qrText,
            boxList,
            frameIndex,
            statusNow,
            defectCount,
          );
        } else {
          tracker.updateTrack(
            qrText,
            boxList,
            frameIndex,
            statusNow,
            defectCount,
          );
        }

        final info = tracker.tracks[qrText]!;
        finalStatus = tracker.computeFinalStatusForDb(info);
      }

      cartonResults.add(
        CartonWithDefects(
          cartonBox: carton,
          defects: defectGlobal,
          qrText: qrText,
          status: finalStatus,
        ),
      );
    }

    // finalize_disappeared + send_to_api
    tracker.finalizeDisappeared(frameIndex,
        (qr, info, finalStatus) async {
      await apiClient.sendProductToApi(
        productId: qr,
        maxDefects: info.maxDefects,
        finalStatus: finalStatus,
      );
    });

    return PipelineResult(cartons: cartonResults);
  }

  RectInt _expandBox(
    Detection box, {
    required int origW,
    required int origH,
    required double expandRatio,
  }) {
    final bw = (box.x2 - box.x1).clamp(1, double.infinity).toDouble();
    final bh = (box.y2 - box.y1).clamp(1, double.infinity).toDouble();

    final padX = (bw * expandRatio).toInt();
    final padY = (bh * expandRatio).toInt();

    int x1 = (box.x1.toInt() - padX).clamp(0, origW - 1);
    int y1 = (box.y1.toInt() - padY).clamp(0, origH - 1);
    int x2 = (box.x2.toInt() + padX).clamp(0, origW - 1);
    int y2 = (box.y2.toInt() + padY).clamp(0, origH - 1);

    return RectInt(
      left: x1,
      top: y1,
      width: (x2 - x1).clamp(0, origW),
      height: (y2 - y1).clamp(0, origH),
    );
  }

  Future<String?> _readQrFromCrop(img.Image crop) async {
    try {
      final rgba = Uint8List.fromList(
        img.copyRotate(crop, angle: 0).getBytes(
              format: img.Format.rgba,
            ),
      );
      final qr = QrCode();
      qr.scanRgbaBytes(rgba, crop.width, crop.height);
      if (qr.content == null) return null;
      final text = qr.content!.text.trim();
      if (text.isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }
}
