import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fires the completion celebration from anywhere (e.g. the provider).
class Celebration {
  Celebration._();

  static final ValueNotifier<int> _trigger = ValueNotifier(0);
  static final Set<String> _celebrated = {};

  /// Celebrates [key] (e.g. "todo:<id>") at most once per day.
  static void fire(String key) {
    final now = DateTime.now();
    final tag = '$key@${now.year}-${now.month}-${now.day}';
    if (!_celebrated.add(tag)) return;
    _trigger.value++;
  }
}

class _Piece {
  Offset pos;
  Offset vel;
  double angle;
  final double spin;
  final double wobble;
  final Color color;
  final Size size;
  final bool circle;

  _Piece(this.pos, this.vel, this.angle, this.spin, this.wobble, this.color,
      this.size, this.circle);
}

/// Full-screen, tap-through confetti layer. Mount once above the app.
/// Two bursts shoot up from the bottom corners while a lighter shower falls
/// from the top. With Reduce Motion on, a brief check-mark pulse is shown
/// instead.
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  const CelebrationOverlay({super.key, required this.child});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addListener(_tick);
  final _rand = math.Random();
  final List<_Piece> _pieces = [];
  Duration _last = Duration.zero;
  Size _size = Size.zero;
  bool _pulse = false;

  // Theme ink + greys + the icon's green.
  static const _colors = [
    Color(0xFF1C1C1E),
    Color(0xFF636366),
    Color(0xFFAEAEB2),
    Color(0xFFFFFFFF),
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];

  @override
  void initState() {
    super.initState();
    Celebration._trigger.addListener(_start);
  }

  @override
  void dispose() {
    Celebration._trigger.removeListener(_start);
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    if (!mounted || _size == Size.zero) return;
    HapticFeedback.mediumImpact();
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _pulse = true);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _pulse = false);
      });
      return;
    }
    _pieces.clear();
    final w = _size.width, h = _size.height;
    // Bursts from the bottom corners, aimed up and inwards.
    for (final fromLeft in [true, false]) {
      for (var i = 0; i < 45; i++) {
        final speed = h * (1.1 + _rand.nextDouble() * 0.7);
        final a = (fromLeft ? -70 : -110) + (_rand.nextDouble() - 0.5) * 30;
        final rad = a * math.pi / 180;
        _pieces.add(_piece(
          Offset(fromLeft ? 0 : w, h),
          Offset(math.cos(rad), math.sin(rad)) * speed,
        ));
      }
    }
    // Lighter shower from the top.
    for (var i = 0; i < 40; i++) {
      _pieces.add(_piece(
        Offset(_rand.nextDouble() * w, -20 - _rand.nextDouble() * h * 0.3),
        Offset((_rand.nextDouble() - 0.5) * 60, 80 + _rand.nextDouble() * 120),
      ));
    }
    _last = Duration.zero;
    _ctrl.forward(from: 0);
  }

  _Piece _piece(Offset pos, Offset vel) => _Piece(
        pos,
        vel,
        _rand.nextDouble() * math.pi,
        (_rand.nextDouble() - 0.5) * 12,
        _rand.nextDouble() * math.pi * 2,
        _colors[_rand.nextInt(_colors.length)],
        Size(6 + _rand.nextDouble() * 5, 3 + _rand.nextDouble() * 4),
        _rand.nextDouble() < 0.25,
      );

  void _tick() {
    final elapsed = _ctrl.lastElapsedDuration ?? Duration.zero;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final gravity = _size.height * 1.3;
    for (final p in _pieces) {
      p.vel = Offset(p.vel.dx * (1 - 1.2 * dt), p.vel.dy + gravity * dt);
      // Terminal velocity so falling pieces flutter instead of plummet.
      if (p.vel.dy > 260) p.vel = Offset(p.vel.dx, 260);
      p.pos += p.vel * dt +
          Offset(math.sin(elapsed.inMilliseconds / 180 + p.wobble) * 0.6, 0);
      p.angle += p.spin * dt;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _size = c.biggest;
      return Stack(
        children: [
          widget.child,
          if (_ctrl.isAnimating)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    _pieces,
                    // Fade out over the last 30%.
                    (1 - (_ctrl.value - 0.7) / 0.3).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          if (_pulse)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Icon(Icons.check_circle, size: 96,
                      color: Color(0xFF10B981)),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double opacity;
  _ConfettiPainter(this.pieces, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      if (p.pos.dy > size.height + 40) continue;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      // Flip on one axis to fake a 3D tumble.
      canvas.scale(1, math.cos(p.angle * 1.7));
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size.height, paint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: p.size.width,
                height: p.size.height),
            paint);
      }
      // Outline so white pieces show on the light theme.
      if (p.color == const Color(0xFFFFFFFF)) {
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero,
                width: p.size.width,
                height: p.size.height),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.6
              ..color = const Color(0x33000000));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
