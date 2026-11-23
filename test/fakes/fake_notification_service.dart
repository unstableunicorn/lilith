import 'package:lilith/data/notifications/notification_service.dart';

/// Records what was scheduled and cancelled.
class FakeNotificationService implements NotificationService {
  final Map<int, Reminder> scheduled = {};
  final List<int> cancelled = [];
  bool permission = true;
  int permissionRequests = 0;

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
  }
}
