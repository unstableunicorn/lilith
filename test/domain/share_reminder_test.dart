import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/share_reminder.dart';

void main() {
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final may1 = DateTime(2026, 5, 1);

  test('a share with an end day is reminded the morning after it', () {
    final share = Share(
      recipientWebId: wife,
      label: 'Alex',
      createdOn: may1,
      expiresOn: DateTime(2026, 5, 31),
    );
    final r = shareReminder(share)!;
    expect(r.at, DateTime(2026, 6, 1, reminderHour));
    expect(r.title, contains('Alex'));
    expect(r.id, shareReminderId(share));
    expect(r.id, greaterThanOrEqualTo(1000));
  });

  test('a share without an end day has no reminder', () {
    expect(
      shareReminder(Share(recipientWebId: wife, label: 'A', createdOn: may1)),
      isNull,
    );
  });

  test('the id is stable per recipient and differs between them', () {
    final a = Share(recipientWebId: wife, label: 'A', createdOn: may1);
    final b = Share(recipientWebId: '${wife}2', label: 'B', createdOn: may1);
    expect(shareReminderId(a), shareReminderId(a));
    expect(shareReminderId(a), isNot(shareReminderId(b)));
  });
}
