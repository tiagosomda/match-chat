import 'package:flutter/material.dart';

import '../models/bracket_layout.dart';

/// Draws the orthogonal elbow lines that connect each match to the one its
/// winner advances to. Painted behind the nodes on the bracket canvas.
class BracketConnectorPainter extends CustomPainter {
  BracketConnectorPainter({
    required this.connectors,
    required this.color,
    required this.emphasizedColor,
  });

  final List<BracketConnector> connectors;
  final Color color;
  final Color emphasizedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    for (final connector in connectors) {
      paint
        ..color = connector.emphasized ? emphasizedColor : color
        ..strokeWidth = connector.emphasized ? 3 : 1.5;
      final pts = connector.points;
      if (pts.length < 2) continue;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(BracketConnectorPainter old) =>
      old.connectors != connectors ||
      old.color != color ||
      old.emphasizedColor != emphasizedColor;
}
