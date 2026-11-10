import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:skribbl_clone/models/touch_points.dart';

/// Fixed virtual canvas dimensions and aspect ratio (4:3)
/// ensures 100% resolution match across all devices regardless of screen size.
const double kCanvasAspectRatio = 4.0 / 3.0;
const double kVirtualCanvasWidth = 1000.0;
const double kVirtualCanvasHeight = 750.0;

class MyCustomPainter extends CustomPainter {
  MyCustomPainter({required this.pointLists});
  final List<TouchPoints?> pointLists;
  List<Offset> offsetPoints = [];

  static const double virtualWidth = kVirtualCanvasWidth;
  static const double virtualHeight = kVirtualCanvasHeight;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw crisp white background filling physical canvas boundaries
    Paint background = Paint()..color = Colors.white;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

    if (size.width <= 0 || size.height <= 0 || pointLists.isEmpty) return;

    // 2. Scale coordinate space from virtual (1000x750) to this device's physical canvas size
    final double scaleX = size.width / virtualWidth;
    final double scaleY = size.height / virtualHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // If only one point is in the list, draw it as a single point
    if (pointLists.length == 1 && pointLists[0] != null) {
      canvas.drawPoints(
        PointMode.points,
        [pointLists[0]!.points],
        pointLists[0]!.paint,
      );
    }

    // Connect points or draw stroke endpoints
    for (int i = 0; i < pointLists.length - 1; i++) {
      final curr = pointLists[i];
      final next = pointLists[i + 1];

      if (curr != null && next != null) {
        canvas.drawLine(
          curr.points,
          next.points,
          curr.paint,
        );
      } else if (curr != null && next == null) {
        canvas.drawPoints(
          PointMode.points,
          [curr.points],
          curr.paint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
