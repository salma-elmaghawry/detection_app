// lib/services/tracker.dart
import '../config.dart';

class TrackInfo {
  List<double> box; // [x1,y1,x2,y2]
  int firstSeen;
  int lastSeen;
  int framesSeen;
  int defectFrames;
  int maxDefects;

  TrackInfo({
    required this.box,
    required this.firstSeen,
    required this.lastSeen,
    required this.framesSeen,
    required this.defectFrames,
    required this.maxDefects,
  });
}

class Tracker {
  final int maxDisappear;
  final Map<String, TrackInfo> _tracks = {};

  Tracker({this.maxDisappear = AppConfig.maxDisappear});

  Map<String, TrackInfo> get tracks => _tracks;

  void createNewTrack(
    String qr,
    List<double> box,
    int frameIndex,
    String statusNow,
    int defectCount,
  ) {
    _tracks[qr] = TrackInfo(
      box: box,
      firstSeen: frameIndex,
      lastSeen: frameIndex,
      framesSeen: 1,
      defectFrames: statusNow == 'defect' ? 1 : 0,
      maxDefects: defectCount,
    );
  }

  void updateTrack(
    String qr,
    List<double> box,
    int frameIndex,
    String statusNow,
    int defectCount,
  ) {
    final info = _tracks[qr]!;
    info.box = box;
    info.lastSeen = frameIndex;
    info.framesSeen += 1;
    if (statusNow == 'defect') {
      info.defectFrames += 1;
    }
    if (defectCount > info.maxDefects) {
      info.maxDefects = defectCount;
    }
  }

  /// نفس compute_final_status_for_db في helpers.py
  String computeFinalStatusForDb(TrackInfo info) {
    final frames = info.framesSeen;
    final df = info.defectFrames;
    final maxDefects = info.maxDefects;

    if (frames <= 3) {
      return df > 0 ? 'defect' : 'ok';
    }

    if (frames == 0) {
      return 'ok';
    }

    final ratio = df / frames;
    if (ratio >= 0.3) {
      return 'defect';
    }

    if (df == 0) {
      return 'ok';
    }

    if (maxDefects >= 2) {
      return 'defect';
    }

    return 'ok';
  }

  /// زي finalize_disappeared في Python،
  /// بس هنا ناخد callback نبعت فيه للـ API.
  void finalizeDisappeared(
    int frameIndex,
    void Function(String qr, TrackInfo info, String finalStatus) onFinalize,
  ) {
    final toRemove = <String>[];
    _tracks.forEach((qr, info) {
      if (frameIndex - info.lastSeen > maxDisappear) {
        final finalStatus = computeFinalStatusForDb(info);
        onFinalize(qr, info, finalStatus);
        toRemove.add(qr);
      }
    });
    for (final qr in toRemove) {
      _tracks.remove(qr);
    }
  }

  /// لليوم اللي تحب تعمل finalize_all_and_send (مثلاً عند إغلاق التطبيق)
  void finalizeAllAndSend(
    void Function(String qr, TrackInfo info, String finalStatus) onFinalize,
  ) {
    final toRemove = <String>[];
    _tracks.forEach((qr, info) {
      final finalStatus = computeFinalStatusForDb(info);
      onFinalize(qr, info, finalStatus);
      toRemove.add(qr);
    });
    for (final qr in toRemove) {
      _tracks.remove(qr);
    }
  }
}
