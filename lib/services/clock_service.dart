import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// Hands alarms to the phone's own Clock app (Android), so a daily habit can
/// ring like a real alarm — snooze, full-screen, alarm volume — not just a
/// notification.
class ClockService {
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens the Clock app with a repeating every-day alarm pre-filled. The
  /// user confirms it there. Returns false if no Clock app can handle it.
  static Future<bool> addDailyAlarm({
    required TimeOfDay time,
    required String label,
  }) async {
    if (!isSupported) return false;
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': time.hour,
        'android.intent.extra.alarm.MINUTES': time.minute,
        'android.intent.extra.alarm.MESSAGE': label,
        // Calendar.SUNDAY (1) … Calendar.SATURDAY (7): every day.
        'android.intent.extra.alarm.DAYS': <int>[1, 2, 3, 4, 5, 6, 7],
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    try {
      if (await intent.canResolveActivity() != true) return false;
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('Could not open the Clock app: $e');
      return false;
    }
  }
}
