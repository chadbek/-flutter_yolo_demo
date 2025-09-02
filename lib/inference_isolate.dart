import 'dart:isolate';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';

import 'utils.dart';

class DetectionBox {
  final double x1;
  final double x2;
  final double y1;
  final double y2;
  final String? cls;
  final double conf;

  DetectionBox({
    required this.x1,
    required this.x2,
    required this.y1,
    required this.y2,
    required this.cls,
    required this.conf,
  });

    // Compute IoU with another DetectionBox
  double iou(DetectionBox other) {
    // Determine the coordinates of the intersection rectangle
    final double interX1 = x1 > other.x1 ? x1 : other.x1;
    final double interY1 = y1 > other.y1 ? y1 : other.y1;
    final double interX2 = x2 < other.x2 ? x2 : other.x2;
    final double interY2 = y2 < other.y2 ? y2 : other.y2;

    // Compute width and height of intersection
    final double interWidth = (interX2 - interX1).clamp(0.0, double.infinity);
    final double interHeight = (interY2 - interY1).clamp(0.0, double.infinity);

    final double interArea = interWidth * interHeight;

    // Compute areas of the boxes
    final double thisArea = (x2 - x1) * (y2 - y1);
    final double otherArea = (other.x2 - other.x1) * (other.y2 - other.y1);

    final double unionArea = thisArea + otherArea - interArea;

    // Avoid division by zero
    if (unionArea == 0) return 0.0;

    return interArea / unionArea;
  }
}


List<DetectionBox> nonMaximumSuppression(
  List<DetectionBox> boxes,
  double iouThreshold,
) {
  // Step 1: Sort boxes by descending confidence
  boxes.sort((a, b) => b.conf.compareTo(a.conf));

  List<DetectionBox> selectedBoxes = [];

  while (boxes.isNotEmpty) {
    final DetectionBox current = boxes.removeAt(0);
    selectedBoxes.add(current);

    // Remove boxes with high IoU overlap with the current box
    boxes = boxes.where((box) => current.iou(box) < iouThreshold).toList();
  }

  return selectedBoxes;
}


class IsolateData {
  final SendPort sendPort;

  IsolateData(this.sendPort);
}


class InferenceMessage {
  final CameraImage image;
  final double confidence_threshold;
  final SendPort responsePort;

  InferenceMessage(this.image, this.confidence_threshold, this.responsePort);
}


class InferenceIsolate {
  static SendPort? _sendPort;
  static late Isolate _isolate;

  static Future<void> spawn(String modelPath) async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, [receivePort.sendPort, modelPath]);
    _sendPort = await receivePort.first as SendPort;
  }

  static void _isolateEntry(List<dynamic> args) async {
    final SendPort initialReplyTo = args[0];
    final String modelPath = args[1];

    InterpreterOptions options = InterpreterOptions();
    options.threads = 1;
    // options.useMetalDelegateForIOS = true;
    final interpreter = await Interpreter.fromFile(File(modelPath), options: options);
    print("✅ Loaded model at: $modelPath");
    final inpShape = interpreter.getInputTensor(0).shape;
    final outShape = interpreter.getOutputTensor(0).shape;

    final port = ReceivePort();
    initialReplyTo.send(port.sendPort);
    final Stopwatch stopwatch = Stopwatch();
    await for (final msg in port) {
      if (msg is InferenceMessage) {
        final image = msg.image;
        final confidence_threshold = msg.confidence_threshold;
        final input = await preprocessCameraImage(image, inpShape[2], inpShape[1]);
        final output = List.generate(1, (_) => List.generate(outShape[1], (_) => List.filled(outShape[2], 0.0)));
        stopwatch.reset();
        stopwatch.start();
        interpreter.run(input, output);
        stopwatch.stop();
        int latency = stopwatch.elapsedMilliseconds;
        print('🕒 Inference time: ${latency} ms');
        // msg.responsePort.send(output);
        List<DetectionBox> boxes = [];
        for (int i = 4; i < outShape[1]; i++) {
          for (int j = 0; j < outShape[2]; j++) {
            var conf = output[0][i][j];
            if (conf < confidence_threshold) {
              continue;
            }
            double xc = output[0][0][j];
            double yc = output[0][1][j];
            double w = output[0][2][j];
            double h = output[0][3][j];
            String? cls = cocoClasses[i-4];
            DetectionBox box = DetectionBox(
              x1: xc-w/2,
              x2: xc+w/2,
              y1: yc-h/2,
              y2: yc+h/2,
              cls: cls,
              conf: conf,
            );

            boxes.add(box);
          }
        }

        var finalDetections = nonMaximumSuppression(boxes, 0.5);
        // for (var box in finalDetections) {
        //   print('${box.cls} @ ${box.conf}');
        // }

        msg.responsePort.send((finalDetections, latency));
      }
    }
  }

  static Future<(List<DetectionBox>, int)> run(CameraImage image, double confidence_threshold) async {
    final responsePort = ReceivePort();
    _sendPort!.send(InferenceMessage(image, confidence_threshold, responsePort.sendPort));
    return await responsePort.first;
  }

  static void dispose() {
    _isolate.kill(priority: Isolate.immediate);
  }
}