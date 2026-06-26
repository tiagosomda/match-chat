import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The football-pitch backdrop: vertical mowing stripes, a center circle, a
/// halfway line and the center spot. Used behind the auth screen and splash.
class PitchBackground extends StatelessWidget {
  const PitchBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg),
      child: CustomPaint(painter: _PitchPainter(c), child: child),
    );
  }
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.c);
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    const stripeWidth = 92.0;
    final paintA = Paint()..color = c.stripeA;
    final paintB = Paint()..color = c.stripeB;
    var x = 0.0;
    var toggle = true;
    while (x < size.width) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeWidth, size.height),
        toggle ? paintA : paintB,
      );
      x += stripeWidth;
      toggle = !toggle;
    }

    final linePaint = Paint()
      ..color = c.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Halfway line.
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      linePaint,
    );
    // Center circle.
    canvas.drawCircle(center, 290, linePaint);
    // Center spot.
    canvas.drawCircle(center, 7, Paint()..color = c.line);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) => old.c != c;
}
