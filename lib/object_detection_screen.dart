import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  File? file;
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<Map<String, dynamic>>? _recognitions;
  var v = "";
  // var dataList = [];
  @override
  void initState() {
    super.initState();
    loadmodel().then((value) {
      setState(() {});
    });
  }

  loadmodel() async {
    _interpreter = await Interpreter.fromAsset('model.tflite');
    final rawLabels = await rootBundle.loadString('assets/labels.txt');
    _labels = rawLabels
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      setState(() {
        _image = image;
        file = File(image!.path);
      });
      detectimage(file!);
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future detectimage(File image) async {
    if (_interpreter == null) return;

    final imageBytes = await image.readAsBytes();
    final oriImage = img.decodeImage(imageBytes);
    if (oriImage == null) return;

    final inputTensor = _interpreter!.getInputTensor(0);
    final shape = inputTensor.shape; // [1,h,w,3]
    final h = shape.length > 1 ? shape[1] : oriImage.height;
    final w = shape.length > 2 ? shape[2] : oriImage.width;

    final resized = img.copyResize(oriImage, width: w, height: h);
    final input = List.generate(
      1,
      (_) =>
          List.generate(h, (_) => List.generate(w, (_) => List.filled(3, 0.0))),
    );
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = resized.getPixel(x, y);
        input[0][y][x][0] = (img.getRed(p) - 127.5) / 127.5;
        input[0][y][x][1] = (img.getGreen(p) - 127.5) / 127.5;
        input[0][y][x][2] = (img.getBlue(p) - 127.5) / 127.5;
      }
    }

    final outT = _interpreter!.getOutputTensor(0);
    final outShape = outT.shape; // [1,labels]
    final labelsCount = outShape.length > 1 ? outShape[1] : _labels.length;
    final output = List.generate(1, (_) => List.filled(labelsCount, 0.0));
    _interpreter!.run(input, output);

    final res = <Map<String, dynamic>>[];
    for (var i = 0; i < labelsCount && i < _labels.length; i++) {
      res.add({'label': _labels[i], 'confidence': output[0][i]});
    }
    res.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );
    final top = res
        .take(6)
        .where((r) => (r['confidence'] as double) > 0.05)
        .toList();
    setState(() {
      _recognitions = top;
      v = _recognitions.toString();
    });
    print(_recognitions);
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: const Text(
          'Object Detection via TFLITE',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_image != null)
              Image.file(
                File(_image!.path),
                height: 200,
                width: 200,
                fit: BoxFit.cover,
              )
            else
              const Text('Pick an image to identify'),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Pick Image from Gallery'),
            ),
            const SizedBox(height: 20),
            Text(v),
          ],
        ),
      ),
    );
  }
}
