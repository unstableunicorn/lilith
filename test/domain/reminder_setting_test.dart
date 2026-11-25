import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/reminder_setting.dart';

void main() {
  test('is off at seven by default and round-trips through JSON', () {
    const s = ReminderSetting();
    expect(s.enabled, isFalse);
    expect(s.hour, 7);
    expect(s.minute, 0);
    const on = ReminderSetting(enabled: true, hour: 21, minute: 30);
    expect(ReminderSetting.fromJson(on.toJson()), on);
    expect(ReminderSetting.fromJson(const {}), s);
  });

  test('period reminders are off, two days before, and load when absent', () {
    const s = ReminderSetting();
    expect(s.beforePeriod, isFalse);
    expect(s.whenLate, isFalse);
    expect(s.daysBefore, 2);
    const on = ReminderSetting(
      beforePeriod: true,
      whenLate: true,
      daysBefore: 4,
    );
    expect(ReminderSetting.fromJson(on.toJson()), on);
    expect(
      ReminderSetting.fromJson(const {'enabled': true, 'hour': 6}),
      const ReminderSetting(enabled: true, hour: 6),
    );
  });

  test('contraception reminders are off, and load when absent', () {
    expect(const ReminderSetting().contraception, isFalse);
    const on = ReminderSetting(contraception: true);
    expect(ReminderSetting.fromJson(on.toJson()).contraception, isTrue);
    expect(ReminderSetting.fromJson(const {}).contraception, isFalse);
  });

  test('the next time is today if still ahead, else tomorrow', () {
    const s = ReminderSetting(enabled: true, hour: 7, minute: 30);
    expect(s.nextAfter(DateTime(2026, 6, 10, 6)), DateTime(2026, 6, 10, 7, 30));
    expect(
      s.nextAfter(DateTime(2026, 6, 10, 7, 30)),
      DateTime(2026, 6, 11, 7, 30),
    );
    expect(s.nextAfter(DateTime(2026, 6, 10, 9)), DateTime(2026, 6, 11, 7, 30));
  });

  test('the reminder carries the daily id and the next time', () {
    const s = ReminderSetting(enabled: true, hour: 8);
    final r = s.reminderAfter(DateTime(2026, 6, 10, 9));
    expect(r.id, dailyReminderId);
    expect(r.at, DateTime(2026, 6, 11, 8));
    expect(r.title, isNotEmpty);
    expect(dailyReminderId, lessThan(1000));
  });
}
