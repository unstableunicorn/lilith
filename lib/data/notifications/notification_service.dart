// Local notifications: scheduled on the device, no server involved.

import 'package:meta/meta.dart';

/// One notification to show at a time.
@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Stable per purpose, so a reschedule replaces rather than adds.
  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, at, title, body);
}

abstract interface class NotificationService {
  /// Whether this device can show scheduled notifications at all.
  bool get isAvailable;

  /// Asks the system once; true when notifications may be shown.
  Future<bool> requestPermission();

  /// Shows [reminder] at its time and again every day at that time of day,
  /// replacing any with the same id.
  Future<void> scheduleDaily(Reminder reminder);

  /// Shows [reminder] at its time, replacing any with the same id. A time
  /// already past is dropped.
  Future<void> schedule(Reminder reminder);

  Future<void> cancel(int id);
}

/// Where notifications cannot be scheduled: the web.
class NoNotificationService implements NotificationService {
  const NoNotificationService();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleDaily(Reminder reminder) async {}

  @override
  Future<void> schedule(Reminder reminder) async {}

  @override
  Future<void> cancel(int id) async {}
}
