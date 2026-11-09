import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:skribbl_clone/models/touch_points.dart';

class MyCustomPainter extends CustomPainter {
  MyCustomPainter({required this.pointLists});
  final List<TouchPoints?> pointLists;
  List<Offset> offsetPoints = [];

  @override
  void paint(Canvas canvas, Size size) {
    Paint background = Paint()..color = Colors.white;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

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
      if (pointLists[i] != null && pointLists[i + 1] != null) {
        canvas.drawLine(
          pointLists[i]!.points,
          pointLists[i + 1]!.points,
          pointLists[i]!.paint,
        );
      } else if (pointLists[i] != null && pointLists[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [
          pointLists[i]!.points,
        ], pointLists[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
