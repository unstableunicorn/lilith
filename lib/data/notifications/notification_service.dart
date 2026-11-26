// Local notifications: scheduled on the device, no server involved.

import 'package:flutter/foundation.dart';

/// A button on a notification.
enum ReminderAction {
  /// Opens the app on Log for today.
  log,

  /// Skips tomorrow's check-in, without opening the app.
  snooze,

  /// Marks today's pill taken, without opening the app.
  taken,

  /// Marks today's patch or ring done, without opening the app.
  done,
}

/// Every set of buttons a reminder may carry. iOS needs each one registered
/// before the app starts.
const List<List<ReminderAction>> reminderActionSets = [
  logActions,
  checkInActions,
  takenActions,
  doneActions,
];

/// On a pill reminder.
const List<ReminderAction> takenActions = [ReminderAction.taken];

/// On a patch or ring reminder.
const List<ReminderAction> doneActions = [ReminderAction.done];

/// On the expected day and once late.
const List<ReminderAction> logActions = [ReminderAction.log];

/// On the daily check-in.
const List<ReminderAction> checkInActions = [
  ReminderAction.log,
  ReminderAction.snooze,
];

/// One notification to show at a time.
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.actions = const [],
    this.payload,
    this.exact = false,
  });

  /// Stable per purpose, so a reschedule replaces rather than adds.
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final List<ReminderAction> actions;

  /// Handed back with a button tap: what the reminder is about.
  final String? payload;

  /// Shown on the minute where the system allows it, else when it can.
  final bool exact;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      listEquals(other.actions, actions) &&
      other.payload == payload &&
      other.exact == exact;

  @override
  int get hashCode =>
      Object.hash(id, at, title, body, Object.hashAll(actions), payload, exact);
}

abstract interface class NotificationService {
  /// Whether this device can show scheduled notifications at all.
  bool get isAvailable;

  /// Asks the system once; true when notifications may be shown.
  Future<bool> requestPermission();

  /// Whether an exact reminder is shown on the minute here.
  Future<bool> canScheduleExact();

  /// Opens the system setting for exact alarms; true once they are allowed.
  Future<bool> requestExact();

  /// Shows [reminder] at its time and again every day at that time of day,
  /// replacing any with the same id.
  Future<void> scheduleDaily(Reminder reminder);

  /// Shows [reminder] at its time, replacing any with the same id. A time
  /// already past is dropped.
  Future<void> schedule(Reminder reminder);

  /// Shows [reminder] now, whatever its time.
  Future<void> show(Reminder reminder);

  Future<void> cancel(int id);

  /// The buttons tapped that open the app, including the one that
  /// launched it.
  Stream<ReminderAction> get opened;

  /// A dose marked done from a notification while the app is running, so
  /// the mark can go to the pod at once.
  Stream<void> get marked;
}

/// Where notifications cannot be scheduled: the web.
class NoNotificationService implements NotificationService {
  const NoNotificationService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExact() async => false;

  @override
  Future<bool> requestExact() async => false;

  @override
  Future<void> scheduleDaily(Reminder reminder) async {}

  @override
  Future<void> schedule(Reminder reminder) async {}

  @override
  Future<void> show(Reminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Stream<ReminderAction> get opened => const Stream.empty();

  @override
  Stream<void> get marked => const Stream.empty();
}
