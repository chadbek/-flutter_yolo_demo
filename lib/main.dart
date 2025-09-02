import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:tflite_flutter/tflite_flutter.dart';

import 'inference_isolate.dart';
import 'utils.dart';
import 'custom_camera.dart';
import 'draggable_button.dart';

late List<CameraDescription> _cameras;
double confidence_threshold = 0.2;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDir = await getApplicationDocumentsDirectory();
  final modelPath = await _copyAssetModelToPath('assets/data/yolo11n_416_float32.tflite', appDir.path);

  await InferenceIsolate.spawn(modelPath);
  _cameras = await availableCameras();
 
  runApp(const CameraApp());
}

Future<String> _copyAssetModelToPath(String assetPath, String destDir) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final file = File('$destDir/yolo.tflite');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// CameraApp is the Main Application.
class CameraApp extends StatefulWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class DetectionPainter extends CustomPainter {
  final List<DetectionBox> boxes;
  int latency = 0;
  double real_w, real_h, left_pad, top_pad;

  DetectionPainter(this.boxes, this.latency, this.real_w, this.real_h, this.left_pad, this.top_pad);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: Colors.red,
      fontSize: 14,
    );

    for (var box in boxes) {
      final rect = Rect.fromLTRB(this.left_pad + box.x1*this.real_w, this.top_pad + box.y1*this.real_h, 
                                 this.left_pad + box.x2*this.real_w, this.top_pad +box.y2*this.real_h);
      canvas.drawRect(rect, paint);

      // Draw class label and confidence
      final textSpan = TextSpan(
        text: '${box.cls} ${(box.conf * 100).toStringAsFixed(1)}%',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(this.left_pad + box.x1*this.real_w, 
                                       this.top_pad + box.y1*this.real_h - 18));
    }

    final cornerText = TextSpan(
      text: '$latency ms', // or any other status text
      style: TextStyle(
        color: const Color.fromARGB(255, 255, 0, 0),
        fontSize: 16,
        // backgroundColor: Colors.black54,
      ),
    );

    final cornerTextPainter = TextPainter(
      text: cornerText,
      textDirection: TextDirection.ltr,
    );

    cornerTextPainter.layout();
    cornerTextPainter.paint(canvas, const Offset(10, 40)); // top-left corner
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  // ui.Image? _image;
  // Uint8List? _image;

  List<DetectionBox> _predictionResult = [];
  int _latency = 0;
  bool _isProcessing = false;
  bool modelIsLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // await InferenceIsolate.spawn();
    controller = CameraController(
      _cameras[0],
      ResolutionPreset.high,
      enableAudio : false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    controller.startImageStream(_handleImage);
  }


  Future<void> _handleImage(CameraImage image) async {    
    if (_isProcessing) return;

    _isProcessing = true;

    var (output, latency) = await InferenceIsolate.run(image, confidence_threshold);

    setState(() {
      // _image = converted;
      _predictionResult = output;
      _latency = latency;
    });

    _isProcessing = false;
  }

  @override
  void dispose() {
    controller.dispose();
    InferenceIsolate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    final Size size = MediaQuery.of(context).size;
    final cam_w = controller.value.previewSize!.width;
    final cam_h = controller.value.previewSize!.height;
    // print("${size.width}x${size.height}, ${cam_w}x${cam_h}");
    double min_ratio = min(size.width / cam_h, size.height / cam_h);
    final real_w = min_ratio * cam_h;
    final real_h = min_ratio * cam_w;
    final top_pad = (size.height - real_h) / 2;
    final left_pad = (size.width - real_w) / 2;
    // print("$real_w, $real_h, $top_pad, $left_pad");

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Center(
              child: CameraPreview(controller),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: DetectionPainter(_predictionResult, _latency, real_w, real_h, left_pad, top_pad),
                // size: Size.infinite,
              ),
            ),
            Positioned(
              child: DraggableThresholdButton(
                onChanged: (value) {
                  print('Threshold updated to $value');
                  confidence_threshold = value;
                  // Use this for ML model, camera tuning, etc.
                },
              ),
              top : top_pad + real_h,
              left : 30,
            ),
          ],
         
        ),
    ),
    );
  }
}