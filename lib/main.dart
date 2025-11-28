// lib/main.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'models/detection.dart';
import 'painters/annotation_painter.dart';
import 'services/api_client.dart';
import 'services/carton_detector.dart';
import 'services/defect_detector.dart';
import 'services/pipeline.dart';
import 'services/tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QC Pipeline (Camera)',
      theme: ThemeData.dark(),
      home: PipelineCameraPage(cameras: cameras),
    );
  }
}

class PipelineCameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const PipelineCameraPage({super.key, required this.cameras});

  @override
  State<PipelineCameraPage> createState() => _PipelineCameraPageState();
}

class _PipelineCameraPageState extends State<PipelineCameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;

  final _cartonDetector = CartonDetector();
  final _defectDetector = DefectDetector();
  final _tracker = Tracker();
  final _apiClient = ApiClient();

  late final CartonPipeline _pipeline;

  Timer? _timer;
  bool _processing = false;
  int _frameIndex = 0;

  PipelineResult? _result;
  ui.Image? _lastUiImage;
  Uint8List? _lastBytes;

  @override
  void initState() {
    super.initState();
    _pipeline = CartonPipeline(
      cartonDetector: _cartonDetector,
      defectDetector: _defectDetector,
      tracker: _tracker,
      apiClient: _apiClient,
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final camera = widget.cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();

      setState(() {
        _initializing = false;
      });

      // كل 500ms ناخد snapshot ونشغّل عليه البايبلاين
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _captureAndProcessFrame();
      });
    } catch (e) {
      setState(() {
        _error = 'Camera error: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _captureAndProcessFrame() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _processing) {
      return;
    }

    try {
      _processing = true;
      _frameIndex++;

      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      _lastBytes = bytes;

      final uiImage = await decodeImageFromList(bytes);
      _lastUiImage = uiImage;

      final result = await _pipeline.runOnImageBytes(
        bytes,
        frameIndex: _frameIndex,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error processing frame: $e';
        });
      }
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('QC Camera Pipeline')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (controller == null || !controller.value.isInitialized)
          ? Center(child: Text(_error ?? 'Camera not available'))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          if (_result != null && _lastUiImage != null)
                            CustomPaint(
                              painter: AnnotationPainter(
                                cartons: _result!.cartons,
                                imageWidth: _lastUiImage!.width.toDouble(),
                                imageHeight: _lastUiImage!.height.toDouble(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_result != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _result!.hasAnyDefect
                          ? 'FINAL STATUS: DEFECT'
                          : 'FINAL STATUS: OK',
                      style: TextStyle(
                        color: _result!.hasAnyDefect
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 18,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}
