import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/providers/talker_provider.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/tables/reminders.dart';

/// Production scheduler backed by `flutter_local_notifications`.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const AndroidNotificationDetails _androidChannel =
      AndroidNotificationDetails(
    'nook_reminders',
    'Note reminders',
    channelDescription: 'Local reminders for your notes',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      nookLog(
        NookLogKey.database,
        'Timezone init failed (using UTC): $e',
        LogLevel.warning,
      );
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  tz.TZDateTime _tz(DateTime dt) {
    try {
      return tz.TZDateTime.from(dt, tz.local);
    } catch (_) {
      return tz.TZDateTime.utc(
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
      );
    }
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {
    await _ensureInitialized();
    final matchDate = _tz(fireAt);
    const details = NotificationDetails(
      android: _androidChannel,
      iOS: DarwinNotificationDetails(),
    );

    DateTimeComponents? components;
    switch (repeat) {
      case ReminderRepeat.none:
        components = null;
      case ReminderRepeat.daily:
        components = DateTimeComponents.time;
      case ReminderRepeat.weekly:
        components = DateTimeComponents.dayOfWeekAndTime;
      case ReminderRepeat.monthly:
        components = DateTimeComponents.dayOfMonthAndTime;
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      matchDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    try {
      await _ensureInitialized();
      await _plugin.cancel(notificationId);
    } catch (e) {
      nookLog(
        NookLogKey.database,
        'Reminder cancel failed: $e',
        LogLevel.warning,
      );
    }
  }

  @override
  Future<void> cancelForNote(String noteId) async {
    // Callers cancel by reminder id via cancelAllForNote; no-op here.
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      await _ensureInitialized();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      nookLog(
        NookLogKey.database,
        'Notification permission request failed: $e',
        LogLevel.warning,
      );
      return false;
    }
  }
}
