import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/widgets/day_progress_arc.dart';

void main() {
  const rise = TimeOfDay(hour: 6, minute: 0);
  const set = TimeOfDay(hour: 18, minute: 0);

  test('midday is halfway through the day', () {
    final p = SkyPhase.at(DateTime(2026, 11, 12, 12), rise, set);
    expect(p.isDay, isTrue);
    expect(p.progress, closeTo(0.5, 1e-9));
    expect(p.remaining, const Duration(hours: 6));
  });

  test('midnight is halfway through the night', () {
    final p = SkyPhase.at(DateTime(2026, 11, 13, 0), rise, set);
    expect(p.isDay, isFalse);
    expect(p.progress, closeTo(0.5, 1e-9));
    expect(p.remaining, const Duration(hours: 6));
  });

  test('just after sunset starts the night', () {
    final p = SkyPhase.at(DateTime(2026, 11, 12, 18, 30), rise, set);
    expect(p.isDay, isFalse);
    expect(p.progress, closeTo(0.5 / 12, 1e-9));
    expect(p.remaining, const Duration(hours: 11, minutes: 30));
  });

  test('before sunrise counts from yesterday evening', () {
    final p = SkyPhase.at(DateTime(2026, 11, 12, 3), rise, set);
    expect(p.isDay, isFalse);
    expect(p.progress, closeTo(9 / 12, 1e-9));
    expect(p.remaining, const Duration(hours: 3));
  });

  test('real-world times: 6:40 sunrise, 5:29 sunset', () {
    final p = SkyPhase.at(
      DateTime(2026, 11, 12, 21, 0),
      const TimeOfDay(hour: 6, minute: 40),
      const TimeOfDay(hour: 17, minute: 29),
    );
    expect(p.isDay, isFalse);
    expect(p.remaining, const Duration(hours: 9, minutes: 40));
  });
}
