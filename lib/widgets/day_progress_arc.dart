import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Where we are in the 24-hour sky cycle.
@immutable
class SkyPhase {
  /// True between sunrise and sunset.
  final bool isDay;

  /// 0.0 at the start of the current day/night, 1.0 at its end.
  final double progress;

  /// Time until the next sunset (day) or sunrise (night).
  final Duration remaining;

  const SkyPhase({
    required this.isDay,
    required this.progress,
    required this.remaining,
  });

  /// Day runs sunrise → sunset; night runs sunset → the next sunrise
  /// (crossing midnight). Yesterday's sunset / tomorrow's sunrise use
  /// today's clock times — they differ by a minute or so.
  static SkyPhase at(DateTime now, TimeOfDay sunrise, TimeOfDay sunset) {
    DateTime on(DateTime day, TimeOfDay t, [int addDays = 0]) =>
        DateTime(day.year, day.month, day.day + addDays, t.hour, t.minute);

    var rise = on(now, sunrise);
    var set = on(now, sunset);
    if (!set.isAfter(rise)) {
      // Unusable times (e.g. polar regions): fall back to 6:00–18:00.
      rise = DateTime(now.year, now.month, now.day, 6);
      set = DateTime(now.year, now.month, now.day, 18);
    }

    SkyPhase between(DateTime start, DateTime end, {required bool day}) {
      final total = end.difference(start).inSeconds;
      final done = now.difference(start).inSeconds;
      return SkyPhase(
        isDay: day,
        progress: total <= 0 ? 0 : (done / total).clamp(0.0, 1.0),
        remaining: end.difference(now),
      );
    }

    if (!now.isBefore(rise) && now.isBefore(set)) {
      return between(rise, set, day: true);
    }
    if (now.isBefore(rise)) {
      // After midnight, before sunrise: night began at yesterday's sunset.
      return between(set.subtract(const Duration(days: 1)), rise, day: false);
    }
    // After sunset: night runs to tomorrow's sunrise.
    return between(
      set,
      DateTime(rise.year, rise.month, rise.day + 1, rise.hour, rise.minute),
      day: false,
    );
  }
}

/// A full 24-hour sky clock.
///
/// The upper half is the day (sunrise on the left, noon at the top, sunset
/// on the right); its mirror below the horizon is the night (sunset →
/// midnight at the bottom → sunrise). One marker travels the loop
/// clockwise: a sun by day, a moon by night. The half that's happening now
/// is drawn at full strength, the other half faded. The digital clock sits
/// in the middle, sunrise/sunset times sit on the horizon, and a line
/// underneath counts down to the next sunset or sunrise.
class DayProgressArc extends StatefulWidget {
  /// Today's sunrise (default 6:00 AM).
  final TimeOfDay sunriseTime;

  /// Today's sunset (default 6:00 PM).
  final TimeOfDay sunsetTime;

  /// Optional override for the current time (testing / previews).
  final DateTime? currentTime;

  /// Height of the circle area (the countdown line is extra).
  final double height;

  /// Thickness of the ring.
  final double arcThickness;

  /// Diameter of the sun / moon marker.
  final double sunSize;

  const DayProgressArc({
    super.key,
    this.sunriseTime = const TimeOfDay(hour: 6, minute: 0),
    this.sunsetTime = const TimeOfDay(hour: 18, minute: 0),
    this.currentTime,
    this.height = 200,
    this.arcThickness = 12,
    this.sunSize = 24,
  });

  @override
  State<DayProgressArc> createState() => _DayProgressArcState();
}

class _DayProgressArcState extends State<DayProgressArc> {
  static const double _labelWidth = 76;

  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _now = widget.currentTime ?? DateTime.now();
    // Check once a second, but only rebuild when the minute changes — the
    // clock, marker and countdown all move in whole minutes. The marker is
    // drawn at its position rather than tweened (it moves a fraction of a
    // pixel per minute, so an animation would have no visible purpose).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = widget.currentTime ?? DateTime.now();
      if (now.minute == _now.minute && now.hour == _now.hour) return;
      setState(() => _now = now);
    });
  }

  @override
  void didUpdateWidget(DayProgressArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTime != widget.currentTime) {
      setState(() => _now = widget.currentTime ?? DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String _duration(Duration d) {
    final minutes = d.inMinutes.clamp(0, 24 * 60);
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phase = SkyPhase.at(_now, widget.sunriseTime, widget.sunsetTime);
    final rise = widget.sunriseTime.format(context);
    final set = widget.sunsetTime.format(context);
    final countdown = phase.isDay
        ? 'Sunset in ${_duration(phase.remaining)}'
        : 'Sunrise in ${_duration(phase.remaining)}';

    return Semantics(
      label: '${phase.isDay ? 'Daytime' : 'Night'}. '
          'Sunrise $rise, sunset $set. $countdown.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, widget.height);
                final center = size.center(Offset.zero);
                final radius = math.max(
                  0.0,
                  math.min(
                    size.width / 2 - _labelWidth - widget.arcThickness / 2 - 8,
                    size.height / 2 - widget.sunSize / 2 - 4,
                  ),
                );
                // Gap between the ring's outer edge and the side labels.
                final labelInset =
                    center.dx - radius - widget.arcThickness / 2 - 14;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SkyCyclePainter(
                          phase: phase,
                          radius: radius,
                          ringThickness: widget.arcThickness,
                          markerSize: widget.sunSize,
                          isDarkTheme: theme.brightness == Brightness.dark,
                        ),
                      ),
                    ),
                    // Clock in the middle of the circle.
                    Positioned.fill(
                      child: Center(child: _buildClock(theme, radius)),
                    ),
                    // Sunrise on the left end of the horizon, sunset on the
                    // right end — where the marker crosses between day and
                    // night.
                    Positioned(
                      left: 0,
                      width: math.max(0, labelInset),
                      top: center.dy - 18,
                      child: _horizonLabel(theme, 'Sunrise', rise,
                          alignEnd: true),
                    ),
                    Positioned(
                      right: 0,
                      width: math.max(0, labelInset),
                      top: center.dy - 18,
                      child: _horizonLabel(theme, 'Sunset', set,
                          alignEnd: false),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                phase.isDay
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                countdown,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _horizonLabel(
    ThemeData theme,
    String title,
    String time, {
    required bool alignEnd,
  }) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildClock(ThemeData theme, double radius) {
    final color = theme.colorScheme.primary;
    // Scale the clock with the circle so it always fits inside the ring.
    final clockSize = (radius * 0.4).clamp(20.0, 48.0);
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$hour:$minute',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: clockSize,
            color: color,
            letterSpacing: -0.03 * clockSize, // tighter as it grows
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 3),
        Padding(
          padding: EdgeInsets.only(top: clockSize * 0.1),
          child: Text(
            period,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: clockSize * 0.34,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the 24-hour ring: day above the horizon, its mirror (night)
/// below, plus the sun or moon marker.
class SkyCyclePainter extends CustomPainter {
  final SkyPhase phase;
  final double radius;
  final double ringThickness;
  final double markerSize;
  final bool isDarkTheme;

  SkyCyclePainter({
    required this.phase,
    required this.radius,
    required this.ringThickness,
    required this.markerSize,
    required this.isDarkTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // One seamless greyscale loop, measured clockwise from the right-hand
    // horizon point (sunset): darkest at midnight (bottom), lightest at
    // sunrise (left), soft at noon (top), back to sunset.
    final colors = isDarkTheme
        ? const [
            Color(0xFF8E8E93), // sunset
            Color(0xFF48484A), // midnight
            Color(0xFFE5E5EA), // sunrise
            Color(0xFFC7C7CC), // noon
            Color(0xFF8E8E93), // sunset again
          ]
        : const [
            Color(0xFF48484A),
            Color(0xFF1C1C1E),
            Color(0xFFD1D1D6),
            Color(0xFFAEAEB2),
            Color(0xFF48484A),
          ];
    final shader = ui.Gradient.sweep(
      center,
      colors,
      const [0.0, 0.25, 0.5, 0.75, 1.0],
      TileMode.clamp,
      0,
      2 * math.pi,
    );

    Paint ring(bool active) => Paint()
      ..shader = shader
      // The half we're in now is solid; the other half is a faint preview.
      ..color = Colors.black.withValues(alpha: active ? 1.0 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness
      ..strokeCap = StrokeCap.butt;

    // Day: from sunrise (left, π) over the top to sunset (right, 2π).
    canvas.drawArc(rect, math.pi, math.pi, false, ring(phase.isDay));
    // Night, the mirror: from sunset (right, 0) under the bottom to sunrise.
    canvas.drawArc(rect, 0, math.pi, false, ring(!phase.isDay));

    _drawHorizon(canvas, center);

    // Marker position: day uses the upper half, night the lower half,
    // both travelling clockwise.
    final angle = phase.isDay
        ? math.pi + phase.progress * math.pi
        : phase.progress * math.pi;
    final position =
        center + Offset(math.cos(angle), math.sin(angle)) * radius;

    if (phase.isDay) {
      _drawSun(canvas, position);
    } else {
      _drawMoon(canvas, position);
    }
  }

  /// Short horizon ticks just outside the ring at sunrise and sunset.
  void _drawHorizon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = (isDarkTheme ? Colors.white : Colors.black)
          .withValues(alpha: isDarkTheme ? 0.35 : 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final outer = radius + ringThickness / 2;
    canvas.drawLine(center + Offset(-outer - 10, 0),
        center + Offset(-outer + 2, 0), paint);
    canvas.drawLine(center + Offset(outer - 2, 0),
        center + Offset(outer + 10, 0), paint);
  }

  void _drawShadow(Canvas canvas, Offset at) {
    canvas.drawCircle(
      at.translate(0, 2),
      markerSize / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: isDarkTheme ? 0.5 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawEdge(Canvas canvas, Path shape) {
    canvas.drawPath(
      shape,
      Paint()
        ..color = isDarkTheme
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Sun: a white disc with a soft shadow.
  void _drawSun(Canvas canvas, Offset at) {
    _drawShadow(canvas, at);
    final disc = Path()
      ..addOval(Rect.fromCircle(center: at, radius: markerSize / 2));
    canvas.drawPath(
      disc,
      Paint()..color = isDarkTheme ? const Color(0xFFF2F2F7) : Colors.white,
    );
    _drawEdge(canvas, disc);
  }

  /// Moon: a pale crescent, lit side facing the direction of travel.
  void _drawMoon(Canvas canvas, Offset at) {
    final r = markerSize / 2;
    _drawShadow(canvas, at);
    final full = Path()..addOval(Rect.fromCircle(center: at, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(
        center: at.translate(-r * 0.55, -r * 0.35),
        radius: r * 0.9,
      ));
    final crescent = Path.combine(PathOperation.difference, full, bite);
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFF2F2F7));
    _drawEdge(canvas, crescent);
  }

  @override
  bool shouldRepaint(SkyCyclePainter old) =>
      old.phase.isDay != phase.isDay ||
      old.phase.progress != phase.progress ||
      old.radius != radius ||
      old.ringThickness != ringThickness ||
      old.markerSize != markerSize ||
      old.isDarkTheme != isDarkTheme;
}
