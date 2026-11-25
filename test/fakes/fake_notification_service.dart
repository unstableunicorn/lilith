import 'dart:async';

import 'package:lilith/data/notifications/notification_service.dart';

/// Records what was scheduled and cancelled; [open] plays a button tap.
class FakeNotificationService implements NotificationService {
  final StreamController<ReminderAction> _opened = StreamController.broadcast(
    sync: true,
  );

  @override
  Stream<ReminderAction> get opened => _opened.stream;

  void open(ReminderAction action) => _opened.add(action);

  final Map<int, Reminder> scheduled = {};
  final Map<int, Reminder> daily = {};
  final List<int> cancelled = [];
  bool available = true;
  bool permission = true;
  int permissionRequests = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<void> scheduleDaily(Reminder reminder) async =>
      daily[reminder.id] = reminder;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> schedule(Reminder reminder) async =>
      scheduled[reminder.id] = reminder;

  /// Whether exact alarms are allowed, and what the system setting answers.
  bool exactAllowed = false;
  bool exactGrant = true;
  int exactRequests = 0;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<bool> requestExact() async {
    exactRequests++;
    return exactAllowed = exactGrant;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    daily.remove(id);
  }
}
