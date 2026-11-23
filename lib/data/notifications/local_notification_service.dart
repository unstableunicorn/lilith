// NotificationService on Android and iOS through flutter_local_notifications.

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const String _channel = 'reminders';

  /// Prepares the plugin once; every call waits for it.
  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
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
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  /// The instant is kept exact by scheduling in UTC: the device's local time
  /// zone database is not needed to say "this many seconds from now".
  @override
  Future<void> schedule(Reminder reminder) async {
    await _init();
    final now = DateTime.now();
    if (!reminder.at.isAfter(now)) return;
    final when = tz.TZDateTime.now(tz.UTC).add(reminder.at.difference(now));
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: when,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channel,
          'Reminders',
          channelDescription: 'Reminders about your shares and logging',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}
