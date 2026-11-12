import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:to_do_list/services/notification_service.dart';

/// Where the sunrise/sunset coordinates came from.
enum SunSource { location, timeZone, estimate }

/// Sunrise and sunset for today, for where the user is, in local time.
///
/// By default the location is estimated from the device time zone (no
/// permission needed). The user can opt in to the device's location for
/// exact times; the last fix is cached so it works offline.
class SunService extends ChangeNotifier {
  static const _kUseLocation = 'sun_use_location';
  static const _kLat = 'sun_lat';
  static const _kLng = 'sun_lng';

  double? _lat;
  double? _lng;
  SunSource _source = SunSource.estimate;
  DateTime? _sunrise;
  DateTime? _sunset;
  Timer? _midnight;

  DateTime? get sunrise => _sunrise;
  DateTime? get sunset => _sunset;
  SunSource get source => _source;
  bool get usesLocation => _source == SunSource.location;

  TimeOfDay? get sunriseTime =>
      _sunrise == null ? null : TimeOfDay.fromDateTime(_sunrise!);
  TimeOfDay? get sunsetTime =>
      _sunset == null ? null : TimeOfDay.fromDateTime(_sunset!);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if ((prefs.getBool(_kUseLocation) ?? false) && lat != null && lng != null) {
      _setCoords(lat, lng, SunSource.location);
    } else {
      _useTimeZoneEstimate();
    }
    _scheduleMidnightRefresh();
  }

  /// Ask for the device's (approximate) location and use it. Returns false
  /// if location is off or permission was refused; times stay unchanged.
  Future<bool> useDeviceLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, // city-level is plenty
          timeLimit: Duration(seconds: 20),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kUseLocation, true);
      await prefs.setDouble(_kLat, position.latitude);
      await prefs.setDouble(_kLng, position.longitude);
      _setCoords(position.latitude, position.longitude, SunSource.location);
      return true;
    } catch (e) {
      debugPrint('Could not get location for sun times: $e');
      return false;
    }
  }

  /// Stop using the device location; go back to the time-zone estimate.
  Future<void> useTimeZone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseLocation, false);
    _useTimeZoneEstimate();
  }

  void _useTimeZoneEstimate() {
    final zone = NotificationService().timeZoneName;
    final known = zone == null ? null : _zoneCoordinates[zone];
    if (known != null) {
      _setCoords(known.$1, known.$2, SunSource.timeZone);
    } else {
      // Unknown zone: longitude from the UTC offset, latitude at the equator.
      final offsetHours = DateTime.now().timeZoneOffset.inMinutes / 60;
      _setCoords(0, offsetHours * 15, SunSource.estimate);
    }
  }

  void _setCoords(double lat, double lng, SunSource source) {
    _lat = lat;
    _lng = lng;
    _source = source;
    _recompute();
  }

  void _recompute() {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return;
    final today = DateTime.now();
    _sunrise = solarEvent(today, lat, lng, rising: true);
    _sunset = solarEvent(today, lat, lng, rising: false);
    notifyListeners();
  }

  void _scheduleMidnightRefresh() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnight = Timer(next.difference(now), () {
      _recompute();
      _scheduleMidnightRefresh();
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    super.dispose();
  }

  /// Sunrise or sunset on [date] at [lat]/[lng], as a local DateTime.
  /// Null when the sun doesn't rise/set that day (polar day or night).
  /// NOAA "sunrise equation" (accurate to a minute or two).
  @visibleForTesting
  static DateTime? solarEvent(
    DateTime date,
    double lat,
    double lng, {
    required bool rising,
  }) {
    const zenith = 90.833; // official: refraction + sun's radius
    double rad(double d) => d * math.pi / 180;
    double deg(double r) => r * 180 / math.pi;
    double norm(double v, double max) => (v % max + max) % max;

    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final lngHour = lng / 15;
    final t = dayOfYear + ((rising ? 6 : 18) - lngHour) / 24;

    final meanAnomaly = 0.9856 * t - 3.289;
    final trueLng = norm(
      meanAnomaly +
          1.916 * math.sin(rad(meanAnomaly)) +
          0.020 * math.sin(rad(2 * meanAnomaly)) +
          282.634,
      360,
    );

    var ra = norm(deg(math.atan(0.91764 * math.tan(rad(trueLng)))), 360);
    ra += (trueLng / 90).floor() * 90 - (ra / 90).floor() * 90;
    ra /= 15;

    final sinDec = 0.39782 * math.sin(rad(trueLng));
    final cosDec = math.cos(math.asin(sinDec));
    final cosH = (math.cos(rad(zenith)) - sinDec * math.sin(rad(lat))) /
        (cosDec * math.cos(rad(lat)));
    if (cosH > 1 || cosH < -1) return null;

    final h = (rising ? 360 - deg(math.acos(cosH)) : deg(math.acos(cosH))) / 15;
    final localMeanTime = h + ra - 0.06571 * t - 6.622;
    final utHours = norm(localMeanTime - lngHour, 24);

    final utcMidnight = DateTime.utc(date.year, date.month, date.day);
    var result = utcMidnight
        .add(Duration(seconds: (utHours * 3600).round()))
        .toLocal();
    // Keep the event on the requested local day.
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day + 1);
    if (result.isBefore(dayStart)) {
      result = result.add(const Duration(days: 1));
    } else if (!result.isBefore(dayEnd)) {
      result = result.subtract(const Duration(days: 1));
    }
    return result;
  }

  // Representative coordinates (capital or main city) for common zones, used
  // when the user hasn't shared their location.
  static const Map<String, (double, double)> _zoneCoordinates = {
    'Asia/Kolkata': (28.61, 77.21),
    'Asia/Calcutta': (28.61, 77.21),
    'Asia/Dhaka': (23.81, 90.41),
    'Asia/Karachi': (24.86, 67.01),
    'Asia/Kathmandu': (27.72, 85.32),
    'Asia/Colombo': (6.93, 79.86),
    'Asia/Thimphu': (27.47, 89.64),
    'Asia/Dubai': (25.20, 55.27),
    'Asia/Riyadh': (24.71, 46.68),
    'Asia/Qatar': (25.29, 51.53),
    'Asia/Tehran': (35.69, 51.39),
    'Asia/Kabul': (34.56, 69.21),
    'Asia/Tashkent': (41.30, 69.24),
    'Asia/Almaty': (43.24, 76.89),
    'Asia/Yangon': (16.87, 96.20),
    'Asia/Bangkok': (13.76, 100.50),
    'Asia/Ho_Chi_Minh': (10.82, 106.63),
    'Asia/Jakarta': (-6.21, 106.85),
    'Asia/Singapore': (1.35, 103.82),
    'Asia/Kuala_Lumpur': (3.14, 101.69),
    'Asia/Manila': (14.60, 120.98),
    'Asia/Shanghai': (31.23, 121.47),
    'Asia/Hong_Kong': (22.32, 114.17),
    'Asia/Taipei': (25.03, 121.57),
    'Asia/Seoul': (37.57, 126.98),
    'Asia/Tokyo': (35.68, 139.69),
    'Asia/Jerusalem': (31.77, 35.21),
    'Europe/London': (51.51, -0.13),
    'Europe/Dublin': (53.35, -6.26),
    'Europe/Lisbon': (38.72, -9.14),
    'Europe/Paris': (48.86, 2.35),
    'Europe/Berlin': (52.52, 13.40),
    'Europe/Madrid': (40.42, -3.70),
    'Europe/Rome': (41.90, 12.50),
    'Europe/Amsterdam': (52.37, 4.90),
    'Europe/Brussels': (50.85, 4.35),
    'Europe/Zurich': (47.38, 8.54),
    'Europe/Vienna': (48.21, 16.37),
    'Europe/Stockholm': (59.33, 18.07),
    'Europe/Oslo': (59.91, 10.75),
    'Europe/Copenhagen': (55.68, 12.57),
    'Europe/Helsinki': (60.17, 24.94),
    'Europe/Warsaw': (52.23, 21.01),
    'Europe/Prague': (50.08, 14.44),
    'Europe/Athens': (37.98, 23.73),
    'Europe/Istanbul': (41.01, 28.98),
    'Europe/Kyiv': (50.45, 30.52),
    'Europe/Moscow': (55.76, 37.62),
    'Africa/Cairo': (30.04, 31.24),
    'Africa/Lagos': (6.52, 3.38),
    'Africa/Nairobi': (-1.29, 36.82),
    'Africa/Johannesburg': (-26.20, 28.05),
    'Africa/Casablanca': (33.57, -7.59),
    'America/New_York': (40.71, -74.01),
    'America/Toronto': (43.65, -79.38),
    'America/Chicago': (41.88, -87.63),
    'America/Denver': (39.74, -104.99),
    'America/Phoenix': (33.45, -112.07),
    'America/Los_Angeles': (34.05, -118.24),
    'America/Vancouver': (49.28, -123.12),
    'America/Anchorage': (61.22, -149.90),
    'Pacific/Honolulu': (21.31, -157.86),
    'America/Mexico_City': (19.43, -99.13),
    'America/Bogota': (4.71, -74.07),
    'America/Lima': (-12.05, -77.04),
    'America/Santiago': (-33.45, -70.67),
    'America/Sao_Paulo': (-23.55, -46.63),
    'America/Argentina/Buenos_Aires': (-34.60, -58.38),
    'Australia/Perth': (-31.95, 115.86),
    'Australia/Adelaide': (-34.93, 138.60),
    'Australia/Brisbane': (-27.47, 153.03),
    'Australia/Sydney': (-33.87, 151.21),
    'Australia/Melbourne': (-37.81, 144.96),
    'Pacific/Auckland': (-36.85, 174.76),
  };
}
