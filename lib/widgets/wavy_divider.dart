import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyDivider extends StatelessWidget {
  final Color lineColor;
  final Color iconColor;
  final double amplitude;
  final double wavelength;

  const WavyDivider({
    super.key,
    required this.lineColor,
    required this.iconColor,
    this.amplitude = 6.0,
    this.wavelength = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 16),
              painter: _SineWavePainter(
                color: lineColor,
                amplitude: amplitude,
                wavelength: wavelength,
                endFraction: 0.44,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(
                painter: _AstroidPainter(color: iconColor),
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 16),
              painter: _SineWavePainter(
                color: lineColor,
                amplitude: amplitude,
                wavelength: wavelength,
                startFraction: 0.56,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AstroidPainter extends CustomPainter {
  final Color color;

  _AstroidPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    for (double i = 0; i <= 360; i += 1) {
      final rad = i * math.pi / 180;
      final x = cx + r * math.pow(math.cos(rad), 3);
      final y = cy + r * math.pow(math.sin(rad), 3);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AstroidPainter old) => old.color != color;
}

class _SineWavePainter extends CustomPainter {
  final Color color;
  final double amplitude;
  final double wavelength;
  final double startFraction;
  final double endFraction;

  _SineWavePainter({
    required this.color,
    required this.amplitude,
    required this.wavelength,
    this.startFraction = 0.0,
    this.endFraction = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    final startX = size.width * startFraction;
    final endX = size.width * endFraction;

    path.moveTo(startX, centerY);

    for (double x = startX; x <= endX; x += 0.5) {
      final y = centerY + amplitude * math.sin((2 * math.pi / wavelength) * x);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SineWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength;
  }
}
