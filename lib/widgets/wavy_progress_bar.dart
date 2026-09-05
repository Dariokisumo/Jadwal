import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A Material 3 Expressive-style animated wavy progress bar.
///
/// Matches the Google M3 Expressive spec:
///   - **Boundary dampening**: wave amplitude is enveloped to zero at the
///     start, at the fill head, and at the end — producing smooth flat
///     endpoints that blend into the track rail.
///   - **Dual layer**: semi-transparent track wave behind, vibrant fill wave
///     clipped to `value × width` in front.
///   - **Animated phase**: continuous rightward scroll giving a liquid-flow feel.
///   - **Value animation**: `value` changes animate with an implicit tween so
///     the fill head glides rather than snapping.
///   - **Reduced-motion safe**: when `animate` is false, phase is locked and
///     value changes are instant.
class WavyProgressBar extends StatefulWidget {
  const WavyProgressBar({
    super.key,
    required this.value,
    required this.activeColor,
    required this.trackColor,
    this.height = 6.0,
    this.amplitude = 2.8,
    this.wavelength = 26.0,
    this.strokeWidth = 2.2,
    this.animate = true,
    this.valueCurve = Curves.easeInOutCubic,
    this.valueDuration = const Duration(milliseconds: 600),
  });

  /// Progress 0.0 – 1.0. Animates to new values when [animate] is true.
  final double value;

  /// Stroke color for the filled (active) portion of the wave.
  final Color activeColor;

  /// Stroke color for the empty track wave.
  final Color trackColor;

  /// Widget height in logical pixels. Waves are vertically centered.
  final double height;

  /// Peak half-amplitude of the sine wave (px).
  /// Keep ≤ (height − strokeWidth) / 2 to avoid clipping.
  final double amplitude;

  /// Wavelength in logical pixels (px per full cycle).
  final double wavelength;

  /// Stroke width for both wave lines.
  final double strokeWidth;

  /// Whether to animate phase + value changes. Set false for reduced motion.
  final bool animate;

  /// Easing for the implicit value → fill head animation.
  final Curve valueCurve;

  /// Duration of the implicit value animation.
  final Duration valueDuration;

  @override
  State<WavyProgressBar> createState() => _WavyProgressBarState();
}

class _WavyProgressBarState extends State<WavyProgressBar>
    with SingleTickerProviderStateMixin {
  // Phase animation controller (drives the rightward wave scroll).
  late final AnimationController _phaseCtrl;

  // Tween for animated value changes.
  late Tween<double> _valueTween;
  late CurvedAnimation _valueAnim;
  double _displayValue = 0.0;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value.clamp(0.0, 1.0);

    _phaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.animate) _phaseCtrl.repeat();

    _valueTween = Tween<double>(begin: _displayValue, end: _displayValue);
    _valueAnim = CurvedAnimation(
      parent: const AlwaysStoppedAnimation(1.0),
      curve: widget.valueCurve,
    );
  }

  @override
  void didUpdateWidget(WavyProgressBar old) {
    super.didUpdateWidget(old);

    // Phase animation on/off.
    if (widget.animate && !old.animate) {
      _phaseCtrl.repeat();
    } else if (!widget.animate && old.animate) {
      _phaseCtrl.stop();
      _phaseCtrl.value = 0;
    }

    // Value animation: start a new tween from the current rendered position.
    final newTarget = widget.value.clamp(0.0, 1.0);
    if (newTarget != old.value.clamp(0.0, 1.0)) {
      if (widget.animate) {
        // Drive value with _phaseCtrl as parent isn't suitable here; we need
        // an independent implicit animation. We'll handle it via a per-frame
        // update by watching the rebuild triggered by _phaseCtrl — so we
        // compute display value from elapsed time manually.
        _displayValue = _displayValue; // snapshot current
        _valueTween = Tween<double>(begin: _displayValue, end: newTarget);
        _valueAnimStart = DateTime.now();
        _valueAnimating = true;
      } else {
        _displayValue = newTarget;
        _valueTween = Tween<double>(begin: newTarget, end: newTarget);
        _valueAnimating = false;
      }
    }
  }

  DateTime _valueAnimStart = DateTime.now();
  bool _valueAnimating = false;

  double _getCurrentDisplayValue() {
    if (!_valueAnimating) return _valueTween.end!;
    final elapsed = DateTime.now().difference(_valueAnimStart);
    final t = (elapsed.inMilliseconds / widget.valueDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    final curved = widget.valueCurve.transform(t);
    final v = _valueTween.transform(curved);
    if (t >= 1.0) {
      _valueAnimating = false;
      _displayValue = _valueTween.end!;
    } else {
      _displayValue = v;
    }
    return _displayValue;
  }

  @override
  void dispose() {
    _phaseCtrl.dispose();
    _valueAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _phaseCtrl,
        builder: (context, _) {
          final dv = _getCurrentDisplayValue();
          return CustomPaint(
            painter: _WavyProgressPainter(
              value: dv,
              activeColor: widget.activeColor,
              trackColor: widget.trackColor,
              amplitude: widget.amplitude,
              wavelength: widget.wavelength,
              strokeWidth: widget.strokeWidth,
              phase: _phaseCtrl.value * 2 * math.pi,
            ),
          );
        },
      ),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _WavyProgressPainter extends CustomPainter {
  _WavyProgressPainter({
    required this.value,
    required this.activeColor,
    required this.trackColor,
    required this.amplitude,
    required this.wavelength,
    required this.strokeWidth,
    required this.phase,
  });

  final double value;
  final Color activeColor;
  final Color trackColor;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;
  final double phase;

  // Width of the dampening zone in px at each boundary.
  // The envelope tapers amplitude to 0 over this distance.
  static const _dampenZone = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final fillWidth = (size.width * value).clamp(0.0, size.width);

    // Both track and fill share the identical wave path — only the clip rect
    // splits the colour. This guarantees the two waves are perfectly in phase
    // at the fill boundary with zero amplitude mismatch.
    final wavePaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── Track (full width, dim) ──────────────────────────────────────────────
    canvas.drawPath(
      _wavePath(0, size.width, centerY),
      wavePaint..color = trackColor,
    );

    // ── Fill (clipped to fillWidth) ──────────────────────────────────────────
    if (fillWidth > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, fillWidth, size.height));
      canvas.drawPath(
        _wavePath(0, size.width, centerY),
        wavePaint..color = activeColor,
      );
      canvas.restore();
    }
  }

  /// Builds a sine-wave [Path] from [startX] to [endX] centered at [centerY].
  ///
  /// Amplitude is dampened to 0 only at the left edge and right edge
  /// (within [_dampenZone] px). The fill boundary is handled purely by a
  /// clip rect so both the track and fill waves are geometrically identical —
  /// no seam or amplitude jump at the fill head.
  Path _wavePath(double startX, double endX, double centerY) {
    final path = Path();
    // Step size — 1 px gives smooth curves without being expensive on mobile.
    const step = 1.0;
    bool started = false;

    for (double x = startX; x <= endX + step; x += step) {
      final xClamped = x.clamp(startX, endX);

      // Dampening envelope [0.0 – 1.0] — edges only, no mid-path flattening.
      final dLeft = (xClamped - startX) / _dampenZone;
      final dRight = (endX - xClamped) / _dampenZone;

      final envelope = math.min(
        dLeft.clamp(0.0, 1.0),
        dRight.clamp(0.0, 1.0),
      );

      // Smooth the envelope with a cubic ease for organic feel.
      final smoothEnvelope = envelope * envelope * (3 - 2 * envelope);

      final y = centerY +
          amplitude *
              smoothEnvelope *
              math.sin((2 * math.pi / wavelength) * xClamped - phase);

      if (!started) {
        path.moveTo(xClamped, y);
        started = true;
      } else {
        path.lineTo(xClamped, y);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(_WavyProgressPainter old) {
    return old.value != value ||
        old.phase != phase ||
        old.activeColor != activeColor ||
        old.trackColor != trackColor ||
        old.amplitude != amplitude ||
        old.wavelength != wavelength ||
        old.strokeWidth != strokeWidth;
  }
}
