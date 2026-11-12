import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class SemiCircleClock extends StatefulWidget {
  const SemiCircleClock({super.key});

  @override
  State<SemiCircleClock> createState() => _SemiCircleClockState();
}

class _SemiCircleClockState extends State<SemiCircleClock> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  int _getCurrentSegment() {
    // Calculate percentage of day completed (0-1)
    final hour = _currentTime.hour;
    final minute = _currentTime.minute;
    const totalMinutesInDay = 24 * 60;
    final currentMinutes = (hour * 60) + minute;
    return ((currentMinutes / totalMinutesInDay) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSegment = _getCurrentSegment();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Semi-circle with time segments
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Semi-circle segments
                CustomPaint(
                  size: const Size(300, 150),
                  painter: SemiCircleClockPainter(
                    dayProgressPercentage: currentSegment,
                    isDark: isDark,
                  ),
                ),

                // Center time display
                Positioned(
                  bottom: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date (small)
                      Text(
                        DateFormat('EEE, MMM d').format(_currentTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Time (large) - 12 hour format
                      Text(
                        DateFormat('hh:mm').format(_currentTime),
                        style: GoogleFonts.oswald(
                          textStyle: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // AM/PM indicator
                      Text(
                        DateFormat('a').format(_currentTime),
                        style: GoogleFonts.oswald(
                          textStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SemiCircleClockPainter extends CustomPainter {
  final int dayProgressPercentage;
  final bool isDark;

  SemiCircleClockPainter({
    required this.dayProgressPercentage,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 20;

    // Background arc (full semi-circle)
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.3)
          : const Color(0xFFE5E7EB);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background arc (180 degrees = full semi-circle)
    canvas.drawArc(
      rect,
      math.pi, // Start at left (180 degrees)
      math.pi, // Sweep 180 degrees to right
      false,
      backgroundPaint,
    );

    // Progress arc (percentage of day completed)
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF10B981); // Green

    // Calculate sweep angle based on percentage
    final sweepAngle = math.pi * (dayProgressPercentage / 100);

    canvas.drawArc(
      rect,
      math.pi, // Start at left
      sweepAngle, // Sweep based on day progress
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(SemiCircleClockPainter oldDelegate) {
    return oldDelegate.dayProgressPercentage != dayProgressPercentage ||
        oldDelegate.isDark != isDark;
  }
}
