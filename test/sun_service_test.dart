import 'package:flutter_test/flutter_test.dart';
import 'package:to_do_list/services/sun_service.dart';

/// Minutes past UTC midnight, so the checks don't depend on the machine's
/// time zone.
int utcMinutes(DateTime t) {
  final u = t.toUtc();
  return u.hour * 60 + u.minute;
}

void main() {
  const tolerance = 5; // minutes

  test('New Delhi, 12 Nov: sunrise ~06:43 IST, sunset ~17:28 IST', () {
    final day = DateTime(2026, 11, 12);
    final rise = SunService.solarEvent(day, 28.61, 77.21, rising: true)!;
    final set = SunService.solarEvent(day, 28.61, 77.21, rising: false)!;
    expect(utcMinutes(rise), closeTo(1 * 60 + 13, tolerance)); // 01:13 UTC
    expect(utcMinutes(set), closeTo(11 * 60 + 58, tolerance)); // 11:58 UTC
  });

  test('London, 21 Jun: sunrise ~04:43 BST, sunset ~21:21 BST', () {
    final day = DateTime(2026, 6, 21);
    final rise = SunService.solarEvent(day, 51.51, -0.13, rising: true)!;
    final set = SunService.solarEvent(day, 51.51, -0.13, rising: false)!;
    expect(utcMinutes(rise), closeTo(3 * 60 + 43, tolerance)); // 03:43 UTC
    expect(utcMinutes(set), closeTo(20 * 60 + 21, tolerance)); // 20:21 UTC
  });

  test('Polar night in Tromsø returns null', () {
    final rise = SunService.solarEvent(
      DateTime(2026, 12, 21),
      69.65,
      18.96,
      rising: true,
    );
    expect(rise, isNull);
  });
}
