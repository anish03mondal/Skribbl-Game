import 'package:flutter/material.dart';

import 'package:skribbl_clone/models/touch_points.dart';

class MyCustomPainter extends CustomPainter {
  MyCustomPainter({required this.pointLists});
  List<TouchPoints> pointLists;
  List<Offset> offsetPoints = [];

  @override
  void paint(Canvas canvas, Size size) {
    Paint background = Paint()..color = Colors.white;
    Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, background);

    //Logic for points
    //if there is point we need to display point
    //if there is line we need to connect the points

    for (int i = 0; i < pointLists.length - 1; i++) {
      //This is a line
      canvas.drawLine(
        pointLists[i].points,
        pointLists[i + 1].points,
        pointLists[i].paint,
      );
        }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
