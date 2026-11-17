import 'dart:io' show Platform;

import 'package:bazaar_sort/services/notifications/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Locally scheduled re-engagement notifications. Nothing is shown unless
/// the player opted in (the OS prompt is only requested after an in-game
/// opt-in). Which notifications to send and when is decided by
/// `NotificationPlanner` (max one a day, quiet hours).
class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Daily rewards, streaks and new bazaar areas',
  );

  @override
  Future<void> initialize() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
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
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  @override
  Future<void> replaceSchedule(
    List<ScheduledNotification> notifications,
  ) async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    for (final n in notifications) {
      await _plugin.zonedSchedule(
        id: n.kind.index,
        scheduledDate: tz.TZDateTime.from(n.when, tz.local),
        notificationDetails: const NotificationDetails(
          android: _android,
          iOS: DarwinNotificationDetails(),
        ),
        // Inexact: no exact-alarm permission needed, battery friendly.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
  }
}
