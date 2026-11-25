// NotificationService on Android and iOS through flutter_local_notifications.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/period_reminder_repository.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Runs in a fresh isolate the plugin starts when a button that does not
/// open the app is tapped, whether or not the app is running.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationAction(NotificationResponse r) async {
  if (r.actionId != ReminderAction.snooze.name) return;
  DartPluginRegistrant.ensureInitialized();
  await snoozeCheckIn(
    SharedPreferencesSettingsStore(),
    LocalNotificationService(),
    now: DateTime.now(),
  );
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<ReminderAction> _opened = StreamController.broadcast();
  Future<void>? _ready;

  static const String _channel = 'reminders';

  /// Prepares the plugin once; every call waits for it. A button that
  /// launched the app is passed on once listeners are there.
  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: darwinCategories,
        ),
      ),
      onDidReceiveNotificationResponse: _tapped,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationAction,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.notificationResponse case final r?
        when launch!.didNotificationLaunchApp) {
      _tapped(r);
    }
  }();

  void _tapped(NotificationResponse r) {
    if (r.actionId == ReminderAction.log.name) _opened.add(ReminderAction.log);
    if (r.actionId == ReminderAction.snooze.name) {
      unawaited(onBackgroundNotificationAction(r));
    }
  }

  @override
  Stream<ReminderAction> get opened {
    unawaited(_init());
    return _opened.stream;
  }

  static AndroidNotificationAction _button(ReminderAction a) => switch (a) {
    ReminderAction.log => AndroidNotificationAction(
      a.name,
      'Log it',
      showsUserInterface: true,
      cancelNotification: true,
    ),
    ReminderAction.snooze => AndroidNotificationAction(
      a.name,
      'Snooze 1 day',
      cancelNotification: true,
    ),
  };

  /// The iOS category that carries [actions], or null for none.
  static String? categoryFor(List<ReminderAction> actions) =>
      actions.isEmpty ? null : actions.map((a) => a.name).join('_');

  /// One iOS category per set of buttons in [reminderActionSets].
  static List<DarwinNotificationCategory> get darwinCategories => [
    for (final set in reminderActionSets)
      DarwinNotificationCategory(
        categoryFor(set)!,
        actions: [for (final a in set) _darwinButton(a)],
      ),
  ];

  static DarwinNotificationAction _darwinButton(ReminderAction a) =>
      switch (a) {
        ReminderAction.log => DarwinNotificationAction.plain(
          a.name,
          'Log it',
          options: const {DarwinNotificationActionOption.foreground},
        ),
        ReminderAction.snooze => DarwinNotificationAction.plain(
          a.name,
          'Snooze 1 day',
        ),
      };

  /// How [reminder] is shown on each platform.
  static NotificationDetails detailsFor(Reminder reminder) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel,
          'Reminders',
          channelDescription: 'Reminders about your period, shares and logging',
          actions: [for (final a in reminder.actions) _button(a)],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: categoryFor(reminder.actions),
        ),
      );

  @override
  bool get isAvailable => true;

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
  Future<void> schedule(Reminder reminder) => _schedule(reminder, repeat: null);

  /// Repeats at the same time of day. The time is held in UTC, so the
  /// reminder drifts by an hour across a daylight-saving change until the
  /// app next runs and schedules it again.
  @override
  Future<void> scheduleDaily(Reminder reminder) =>
      _schedule(reminder, repeat: DateTimeComponents.time);

  Future<void> _schedule(
    Reminder reminder, {
    required DateTimeComponents? repeat,
  }) async {
    await _init();
    final now = DateTime.now();
    if (!reminder.at.isAfter(now)) return;
    final when = tz.TZDateTime.now(tz.UTC).add(reminder.at.difference(now));
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: when,
      title: reminder.title,
      body: reminder.body,
      notificationDetails: detailsFor(reminder),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeat,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }
}
