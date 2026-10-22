/// Platform binding for the hourly logging reminders — the
/// Flutter counterpart of the Kotlin `ReminderScheduler`.
///
/// The original used an inexact hourly AlarmManager alarm and, at
/// fire time, skipped the notification when the current hour
/// already had a log. A notification plugin cannot run Dart code
/// at delivery time, so this port instead pre-schedules one
/// daily-repeating inexact alarm per allowed hour (quiet hours
/// excluded) via flutter_local_notifications. The reminder copy is
/// the original's: "Time to log care" / "Who's been with the baby
/// this hour? Tap to log it."
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

/// Channel id / user-visible name — the original's
/// NotificationCompat channel "logging_reminders".
const _channelId = 'logging_reminders';
const _channelName = 'Logging reminders';

const _title = 'Time to log care';
const _body = "Who's been with the baby this hour? Tap to log it.";

class ReminderService {
  ReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC rather than skipping reminders entirely.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Requests POST_NOTIFICATIONS on Android 13+ (or the iOS alert
  /// permission). Returns whether notifications can be shown.
  /// Reminders are best-effort: any platform failure reads as
  /// "not granted" rather than crashing the caller.
  static Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await ios?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('FairCare: reminder permission request failed: $e');
    }
    return false;
  }

  /// Rebuilds the whole schedule from [settings]: clears every
  /// pending reminder, then (when enabled) schedules one
  /// daily-repeating inexact alarm per allowed hour. Best-effort —
  /// platform failures are logged, never thrown.
  static Future<void> applySettings(ReminderSettings settings) async {
    try {
      await _ensureInitialized();
      await _plugin.cancelAllPendingNotifications();
      if (!settings.enabled) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
      final now = DateTime.now();
      for (final hour in settings.allowedHours) {
        var when =
            tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, 0);
        if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
          when = when.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id: hour,
          title: _title,
          body: _body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('FairCare: applying reminder settings failed: $e');
    }
  }
}
