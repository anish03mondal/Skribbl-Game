import 'package:flutter/material.dart';

class TouchPoints {
  //This variable holds a Paint object, which defines how to draw the point: color, stoke width, style
  Paint paint;
  //This stores the actual 2D coordinates (x, y) of the touch on the screen using Flutter’s Offset class.
  Offset points;

  TouchPoints({required this.points, required this.paint});

  Map<String, dynamic> toJson() {
    return {
      'point': {'dx': '${points.dx}', 'dy': '${points.dy}'},
    };
  }
}
