import 'package:camera/camera.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import 'package:image/image.dart' as img;

final Map<int, String> cocoClasses = {
  0: 'person', 1: 'bicycle', 2: 'car', 3: 'motorcycle', 4: 'airplane', 5: 'bus', 6: 'train', 7: 'truck', 8: 'boat', 9: 'traffic light',
  10: 'fire hydrant', 11: 'stop sign', 12: 'parking meter', 13: 'bench', 14: 'bird', 15: 'cat', 16: 'dog', 17: 'horse', 18: 'sheep', 19: 'cow',
  20: 'elephant', 21: 'bear', 22: 'zebra', 23: 'giraffe', 24: 'backpack', 25: 'umbrella', 26: 'handbag', 27: 'tie', 28: 'suitcase', 29: 'frisbee',
  30: 'skis', 31: 'snowboard', 32: 'sports ball', 33: 'kite', 34: 'baseball bat', 35: 'baseball glove', 36: 'skateboard', 37: 'surfboard',
  38: 'tennis racket', 39: 'bottle', 40: 'wine glass', 41: 'cup', 42: 'fork', 43: 'knife', 44: 'spoon', 45: 'bowl', 46: 'banana', 47: 'apple',
  48: 'sandwich', 49: 'orange', 50: 'broccoli', 51: 'carrot', 52: 'hot dog', 53: 'pizza', 54: 'donut', 55: 'cake', 56: 'chair', 57: 'couch',
  58: 'potted plant', 59: 'bed', 60: 'dining table', 61: 'toilet', 62: 'tv', 63: 'laptop', 64: 'mouse', 65: 'remote', 66: 'keyboard', 67: 'cell phone',
  68: 'microwave', 69: 'oven', 70: 'toaster', 71: 'sink', 72: 'refrigerator', 73: 'book', 74: 'clock', 75: 'vase', 76: 'scissors', 77: 'teddy bear',
  78: 'hair drier', 79: 'toothbrush'
};


Future<List> preprocessCameraImage(CameraImage image, int input_width, int input_height) async {
  img.Image rgbImage = convertYUV420toImage(image);

  // Resize it using image package
  img.Image resized = img.copyResize(rgbImage, width: input_width, height: input_height);

  List input = List.generate(
    1,
    (_) => List.generate(input_height, (y) =>
      List.generate(input_width, (x) {
        final pixel = resized.getPixel(x, y);
        return [
          pixel.r / 255.0,
          pixel.g / 255.0,
          pixel.b / 255.0
        ];
      })
    )
  );

  return input;
}


img.Image convertYUV420toImage(CameraImage image) {
  int width = image.width;
  int height = image.height;

  final yBytes = image.planes[0].bytes;
  final uvBytes = image.planes[1].bytes;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel ?? 2; // Typically 2

  // Uint8List rgb = Uint8List(width * height * 3);
  final img.Image rgbImage = img.Image(width: width, height: height);


  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * image.planes[0].bytesPerRow + x;
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      final Y = yBytes[yIndex];
      final Cb = uvBytes[uvIndex];
      final Cr = uvBytes[uvIndex + 1];

      int R = (Y + 1.402 * (Cr - 128)).round();
      int G = (Y - 0.344136 * (Cb - 128) - 0.714136 * (Cr - 128)).round();
      int B = (Y + 1.772 * (Cb - 128)).round();

      R = R.clamp(0, 255);
      G = G.clamp(0, 255);
      B = B.clamp(0, 255);

      // int index = (y * width + x) * 3;
      rgbImage.setPixelRgb(x, y, R, G, B);
    }
  }

  return rgbImage;
}

img.Image convertYUV420toRGBAImage(CameraImage image) {
  int width = image.width;
  int height = image.height;

  final yBytes = image.planes[0].bytes;
  final uvBytes = image.planes[1].bytes;
  final uvRowStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel ?? 2; // Typically 2

  // Uint8List rgb = Uint8List(width * height * 3);
  final img.Image rgbaImage = img.Image(width: width, height: height, format: img.Format.uint8, numChannels: 4);


  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * image.planes[0].bytesPerRow + x;
      final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      final Y = yBytes[yIndex];
      final Cb = uvBytes[uvIndex];
      final Cr = uvBytes[uvIndex + 1];

      int R = (Y + 1.402 * (Cr - 128)).round();
      int G = (Y - 0.344136 * (Cb - 128) - 0.714136 * (Cr - 128)).round();
      int B = (Y + 1.772 * (Cb - 128)).round();

      R = R.clamp(0, 255);
      G = G.clamp(0, 255);
      B = B.clamp(0, 255);

      // int index = (y * width + x) * 3;
      rgbaImage.setPixelRgba(x, y, R, G, B, 255);
    }
  }

  return rgbaImage;
}


Future<ui.Image> imageToUiImage(img.Image image) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();

  // Get RGBA bytes
  final Uint8List rgbaBytes = image.getBytes(order: img.ChannelOrder.rgba);

  // Convert to dart:ui.Image
  ui.decodeImageFromPixels(
    rgbaBytes,
    image.width,
    image.height,
    ui.PixelFormat.rgba8888,
    (ui.Image result) {
      completer.complete(result);
    },
  );

  return completer.future;
}