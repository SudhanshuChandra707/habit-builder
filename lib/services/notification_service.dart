import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:to_do_list/models/todo.dart' hide Priority;
import 'package:to_do_list/models/daily_task.dart';
import 'package:to_do_list/models/habit.dart';

/// What a tapped notification (or its "Mark done" button) asks the app to do.
class NotificationIntent {
  final String kind; // 'todo' | 'daily' | 'habit'
  final String id;
  final int? index; // habit interval
  final bool markDone;

  const NotificationIntent(this.kind, this.id, {this.index, this.markDone = false});
}

/// Schedules every reminder the app sends, in the device's own time zone.
///
/// * To-dos: "due in 15 min" + "due now" for timed to-dos, 9:00 "due today"
///   for all-day ones.
/// * Daily habits: a repeating alert at the reminder time, plus a follow-up
///   an hour later on days it isn't done yet.
/// * Interval habits: an alert when each day/hour starts that counts down
///   to the end of the interval, a "time running out" alert before it ends,
///   and a quiet live countdown for the interval that is running now.
///
/// Every alert has a "Mark done" button.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// IANA name of the device time zone, e.g. "Asia/Kolkata" (null if unknown).
  String? timeZoneName;

  bool _ready = false;
  bool _exactAlarms = false;

  final _intents = StreamController<NotificationIntent>.broadcast();
  Stream<NotificationIntent> get intents => _intents.stream;
  NotificationIntent? _launchIntent;

  /// The notification that cold-started the app, if any (returned once).
  NotificationIntent? takeLaunchIntent() {
    final intent = _launchIntent;
    _launchIntent = null;
    return intent;
  }

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // ------------------------------------------------------------- channels

  static const _doneAction = AndroidNotificationAction(
    'done',
    'Mark done',
    showsUserInterface: true,
    cancelNotification: true,
  );

  static const _darwinCategory = 'reminder';

  static const _darwin = DarwinNotificationDetails(
    categoryIdentifier: _darwinCategory,
  );

  /// To-do due alerts.
  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'To-do reminders',
      channelDescription: 'Alerts when a to-do is due',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [_doneAction],
    ),
    iOS: _darwin,
    macOS: _darwin,
  );

  /// Daily-habit and habit-interval alerts.
  static NotificationDetails _habitDetails({DateTime? countdownTo}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_alerts',
        'Habit alerts',
        channelDescription:
            'Alerts when it is time for a habit and when time is running out',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: const [_doneAction],
        // Shows a live "time left" countdown while the habit window is on.
        when: countdownTo?.millisecondsSinceEpoch,
        usesChronometer: countdownTo != null,
        chronometerCountDown: countdownTo != null,
      ),
      iOS: _darwin,
      macOS: _darwin,
    );
  }

  /// Quiet, live countdown for the habit interval that is running now.
  static NotificationDetails _progressDetails(DateTime end) {
    final remaining = end.difference(DateTime.now()).inMilliseconds;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_progress',
        'Habit in progress',
        channelDescription:
            'A silent countdown while a habit interval is running',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        actions: const [_doneAction],
        when: end.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        timeoutAfter: remaining > 0 ? remaining : null,
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: _darwinCategory,
        presentSound: false,
        interruptionLevel: InterruptionLevel.passive,
      ),
    );
  }

  // ---------------------------------------------------------------- setup

  Future<void> init() async {
    // Device time zone, so "9:00" means 9:00 here (tz.local defaults to UTC).
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      timeZoneName = info.identifier;
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Could not read device time zone: $e');
    }

    if (!_supported) return;

    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _darwinCategory,
          actions: [
            DarwinNotificationAction.plain(
              'done',
              'Mark done',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        // Status-bar icon must be a one-colour silhouette; the full-colour
        // launcher icon would show as a blank white square.
        android: const AndroidInitializationSettings('@drawable/ic_stat_notify'),
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final intent = _parse(response);
        if (intent != null) _intents.add(intent);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch!.notificationResponse != null) {
      _launchIntent = _parse(launch.notificationResponse!);
    }
    _ready = true;
  }

  Future<void> requestPermissions() async {
    if (!_ready) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      _exactAlarms = await android.canScheduleExactNotifications() ?? false;
      if (!_exactAlarms) {
        // Android 14+ doesn't grant exact alarms by default. Ask once; if the
        // user declines, reminders still arrive, just possibly a few minutes
        // late.
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('asked_exact_alarms') ?? false)) {
          await prefs.setBool('asked_exact_alarms', true);
          await android.requestExactAlarmsPermission();
          _exactAlarms = await android.canScheduleExactNotifications() ?? false;
        }
      }
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  AndroidScheduleMode get _mode => _exactAlarms
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // ------------------------------------------------------------------ ids

  static const _slots = 24;

  /// Stable per-item notification id: FNV-1a hash of the item id plus a
  /// slot number, so one item can own several alerts.
  static int _notificationId(String key, int slot) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (hash % 1000000) * 32 + slot;
  }

  String _payload(String kind, String id, [int? index]) =>
      index == null ? '$kind|$id' : '$kind|$id|$index';

  NotificationIntent? _parse(NotificationResponse response) {
    final parts = (response.payload ?? '').split('|');
    if (parts.length < 2) return null;
    return NotificationIntent(
      parts[0],
      parts[1],
      index: parts.length > 2 ? int.tryParse(parts[2]) : null,
      markDone: response.actionId == 'done',
    );
  }

  /// Cancels every alert belonging to one to-do / habit.
  Future<void> cancelNotification(String id) async {
    if (!_ready) return;
    for (var slot = 0; slot < _slots; slot++) {
      await _plugin.cancel(id: _notificationId(id, slot));
    }
    await _plugin.cancel(id: id.hashCode); // ids used by older versions
  }

  Future<void> _schedule({
    required String key,
    required int slot,
    required DateTime at,
    required String title,
    required String body,
    required NotificationDetails details,
    required String payload,
    DateTimeComponents? repeat,
  }) async {
    if (!at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _notificationId(key, slot),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: details,
        androidScheduleMode: _mode,
        matchDateTimeComponents: repeat,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Could not schedule "$title": $e');
    }
  }

  /// Clears everything and schedules all alerts again (app start).
  Future<void> rescheduleAll({
    required List<Todo> todos,
    required List<DailyTask> dailyTasks,
    required List<Habit> habits,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final todo in todos) {
      await scheduleTodoReminder(todo, cancelFirst: false);
    }
    for (final task in dailyTasks) {
      await scheduleDailyTaskReminder(task, cancelFirst: false);
    }
    for (final habit in habits) {
      await scheduleHabitReminder(habit, cancelFirst: false);
    }
  }

  // ---------------------------------------------------------------- to-dos

  Future<void> scheduleTodoReminder(Todo todo, {bool cancelFirst = true}) async {
    if (!_ready) return;
    if (cancelFirst) await cancelNotification(todo.id);
    if (todo.isCompleted || todo.dueDate == null) return;

    final due = todo.dueDate!;
    final payload = _payload('todo', todo.id);

    if (todo.hasDueTime) {
      await _schedule(
        key: todo.id,
        slot: 0,
        at: due.subtract(const Duration(minutes: 15)),
        title: todo.title,
        body: 'Due in 15 minutes',
        details: _taskDetails,
        payload: payload,
      );
      await _schedule(
        key: todo.id,
        slot: 1,
        at: due,
        title: todo.title,
        body: todo.description.isNotEmpty
            ? 'Due now · ${todo.description}'
            : 'Due now',
        details: _taskDetails,
        payload: payload,
      );
    } else {
      await _schedule(
        key: todo.id,
        slot: 0,
        at: DateTime(due.year, due.month, due.day, 9),
        title: todo.title,
        body: todo.description.isNotEmpty
            ? 'Due today · ${todo.description}'
            : 'Due today',
        details: _taskDetails,
        payload: payload,
      );
    }
  }

  // ---------------------------------------------------------- daily habits

  Future<void> scheduleDailyTaskReminder(
    DailyTask task, {
    bool cancelFirst = true,
  }) async {
    if (!_ready) return;
    if (cancelFirst) await cancelNotification(task.id);
    if (!task.reminderEnabled) return;

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      task.reminderTime.hour,
      task.reminderTime.minute,
    );
    // Repeats every day at the reminder time. If it's already done today
    // (or the time has passed), the first one is tomorrow.
    final first = task.isCompletedToday || !today.isAfter(now)
        ? DateTime(today.year, today.month, today.day + 1, today.hour,
            today.minute)
        : today;
    final payload = _payload('daily', task.id);

    await _schedule(
      key: task.id,
      slot: 0,
      at: first,
      title: 'Time for ${task.title}',
      body: task.description.isNotEmpty
          ? task.description
          : 'Your daily habit is on now',
      details: _habitDetails(),
      payload: payload,
      repeat: DateTimeComponents.time,
    );

    // A nudge an hour later, today only, if it still isn't done.
    final nudge = today.add(const Duration(hours: 1));
    if (!task.isCompletedToday && nudge.day == today.day) {
      await _schedule(
        key: task.id,
        slot: 1,
        at: nudge,
        title: '${task.title} — not done yet',
        body: 'Still time today. Tap Mark done when you have.',
        details: _habitDetails(),
        payload: payload,
      );
    }
  }

  // -------------------------------------------------------- interval habits

  static const _window = 10; // upcoming intervals scheduled ahead

  Future<void> scheduleHabitReminder(Habit habit, {bool cancelFirst = true}) async {
    if (!_ready) return;
    if (cancelFirst) await cancelNotification(habit.id);
    if (habit.isCompleted || habit.targetCount <= 0) return;

    final isDays = habit.durationType == HabitDurationType.days;
    final start = habit.startDate ?? habit.createdAt;
    DateTime intervalStart(int i) => isDays
        ? DateTime(start.year, start.month, start.day + i)
        : start.add(Duration(hours: i));
    DateTime intervalEnd(int i) => intervalStart(i + 1);
    String label(int i) =>
        '${isDays ? 'Day' : 'Hour'} ${i + 1} of ${habit.targetCount}';
    bool done(int i) =>
        i < habit.completionStatus.length && habit.completionStatus[i];

    final now = DateTime.now();
    final current = habit.getCurrentIntervalIndex();
    final last = habit.targetCount - 1;

    // Live countdown for the interval that's on right now.
    if (current >= 0 && current <= last && !done(current)) {
      final end = intervalEnd(current);
      try {
        await _plugin.show(
          id: _notificationId(habit.id, 20),
          title: '${habit.title} · ${label(current)}',
          body: 'On now — mark it done before the timer runs out',
          notificationDetails: _progressDetails(end),
          payload: _payload('habit', habit.id, current),
        );
      } catch (e) {
        debugPrint('Could not show habit progress: $e');
      }
    }

    // Alerts as each upcoming interval starts (days: at 8:00, not midnight).
    final firstUpcoming = current < 0 ? 0 : current + 1;
    for (var i = firstUpcoming;
        i <= last && i < firstUpcoming + _window;
        i++) {
      final begins = intervalStart(i);
      final alertAt = isDays
          ? DateTime(begins.year, begins.month, begins.day, 8)
          : begins;
      await _schedule(
        key: habit.id,
        slot: i - firstUpcoming,
        at: alertAt,
        title: '${habit.title} · ${label(i)}',
        body: isDays ? 'Today is on — tap Mark done once it\'s done' : 'Starts now',
        details: _habitDetails(countdownTo: intervalEnd(i)),
        payload: _payload('habit', habit.id, i),
      );
    }

    // "Time running out" before each open interval ends (days: 3 h, hours:
    // 10 min). Completed intervals are skipped; completing one reschedules.
    final firstOpen = current < 0 ? 0 : current;
    final lead = isDays ? const Duration(hours: 3) : const Duration(minutes: 10);
    for (var i = firstOpen; i <= last && i < firstOpen + _window; i++) {
      if (done(i)) continue;
      final end = intervalEnd(i);
      final at = end.subtract(lead);
      if (!at.isAfter(now)) continue;
      await _schedule(
        key: habit.id,
        slot: 10 + (i - firstOpen),
        at: at,
        title: '${habit.title} · ${label(i)}',
        body: isDays
            ? '3 hours left today to complete it'
            : '10 minutes left in this hour',
        details: _habitDetails(countdownTo: end),
        payload: _payload('habit', habit.id, i),
      );
    }
  }
}
