import 'package:lilith/data/notifications/notification_service.dart';

/// Records what was scheduled and cancelled.
class FakeNotificationService implements NotificationService {
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

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
    daily.remove(id);
  }
}
