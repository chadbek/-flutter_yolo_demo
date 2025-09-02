import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class CustomCameraPreview extends StatelessWidget {
  final ui.Image? image;

  const CustomCameraPreview({Key? key, this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CustomImagePainter(image),
      size: Size.infinite,
    );
  }
}

class _CustomImagePainter extends CustomPainter {
  final ui.Image? image;

  _CustomImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      paintImage(
        canvas: canvas,
        image: image!,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        fit: BoxFit.cover,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CustomImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}