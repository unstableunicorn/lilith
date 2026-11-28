import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/period_reminder_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';

import '../fakes/fake_notification_service.dart';
import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';

/// What a life factor changes outside Today: shares, the report and the
/// period reminders.
void main() {
  const codec = HealthDocumentCodec();
  final now = DateTime(2026, 5, 20, 9);
  final today = DateTime(2026, 5, 20);
  final pregnant = LifeFactor(
    kind: LifeFactorKind.pregnant,
    start: DateTime(2026, 5, 10),
    dueDate: DateTime(2027, 2, 8),
  );

  HealthData history({List<LifeFactor> factors = const []}) {
    var d = HealthData.empty.withProfile(
      HealthProfile(
        contraception: Contraception.copperIud,
        notes: 'private',
        lifeFactors: factors,
      ),
    );
    for (final s in [
      DateTime(2026, 2, 9),
      DateTime(2026, 3, 8),
      DateTime(2026, 4, 6),
      DateTime(2026, 5, 4),
    ]) {
      d = d.withPeriod(
        PeriodEvent(startDate: s, endDate: s.add(const Duration(days: 4))),
      );
    }
    return d;
  }

  group('a full share', () {
    test('carries the life factors, and still nothing else of the '
        'profile', () {
      final shared = sharedView(history(factors: [pregnant]));
      expect(shared.profile.lifeFactors, [pregnant]);
      expect(shared.profile.notes, isEmpty);
      expect(shared.profile.contraception, isNull);
    });

    test('with contraception shared, carries both', () {
      final shared = sharedView(
        history(factors: [pregnant]),
        includeContraception: true,
      );
      expect(shared.profile.lifeFactors, [pregnant]);
      expect(shared.profile.contraception, Contraception.copperIud);
    });

    test('without factors the shared profile stays empty', () {
      expect(sharedView(history()).profile.isEmpty, isTrue);
    });
  });

  group('a phases share', () {
    SharedPhases phases(HealthData data) => sharedPhases(
      data,
      today: today,
      fertileWindowMode: FertileWindowMode.information,
    );

    test('says it is paused, without the reason or a next period', () {
      final p = phases(history(factors: [pregnant]));
      expect(p.paused, isTrue);
      expect(p.nextPeriod, isNull);
      expect(p.ovulation, isNull);
      expect(p.fertileWindow, isNull);
      expect(jsonEncode(p.toJson()), isNot(contains('pregnant')));
      expect(p.toJson()['paused'], isTrue);
    });

    test('is not paused without a factor, and writes no key', () {
      final p = phases(history());
      expect(p.paused, isFalse);
      expect(p.nextPeriod, isNotNull);
      expect(p.toJson().containsKey('paused'), isFalse);
    });

    test('paused round-trips and is part of what it equals', () {
      final p = phases(history(factors: [pregnant]));
      final again = SharedPhases.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(again.paused, isTrue);
      expect(again, p);
      expect(
        SharedPhases(updatedOn: today, paused: true),
        isNot(SharedPhases(updatedOn: today)),
      );
    });

    test('waiting for a period after a factor counts as paused', () {
      final p = phases(
        history(factors: [pregnant.endedOn(DateTime(2026, 5, 15))]),
      );
      expect(p.paused, isTrue);
    });
  });

  group('the report', () {
    ReportContent report(HealthData data) =>
        reportContent(data, range: ExportRange.all, today: today);
    String? row(List<(String, String)> rows, String label) =>
        rows.where((r) => r.$1 == label).map((r) => r.$2).firstOrNull;

    test('notes an active factor in the summary and gives no next period', () {
      final c = report(history(factors: [pregnant]));
      expect(row(c.summary, 'Predictions'), 'Paused: pregnant');
      expect(row(c.summary, 'Predicted next period'), isNull);
      expect(row(c.summary, 'Last period started'), isNull);
    });

    test('lists every factor in the profile, with its dates', () {
      final c = report(
        history(
          factors: [
            LifeFactor(
              kind: LifeFactorKind.miscarriage,
              start: DateTime(2025, 11, 3),
              end: DateTime(2025, 12, 1),
            ),
            pregnant,
          ],
        ),
      );
      expect(
        row(c.profile, 'Pregnancy and breastfeeding'),
        'Miscarriage on 2025-11-03; '
        'Pregnant from 2026-05-10 (ongoing), due 2027-02-08',
      );
    });

    test('an ended factor gives both days', () {
      final c = report(
        history(factors: [pregnant.endedOn(DateTime(2026, 5, 15))]),
      );
      expect(
        row(c.profile, 'Pregnancy and breastfeeding'),
        'Pregnant from 2026-05-10 to 2026-05-15',
      );
      expect(
        row(c.summary, 'Predictions'),
        'Paused until the next period is logged',
      );
    });

    test('without factors says nothing about them', () {
      final c = report(history());
      expect(row(c.summary, 'Predictions'), isNull);
      expect(row(c.profile, 'Pregnancy and breastfeeding'), isNull);
      expect(row(c.summary, 'Predicted next period'), isNotNull);
    });
  });

  group('period reminders', () {
    late FakeNotificationService notifications;

    Future<void> start(HealthData data) async {
      final pod = FakePodService();
      final health = HealthRepository(pod, protection: DataProtection.plain);
      pod.documents[health.documentPath] = codec.encode(data);
      final settings = FakeSettingsStore()
        ..reminder = const ReminderSetting(beforePeriod: true, whenLate: true);
      notifications = FakeNotificationService();
      final reminders = ReminderRepository(
        settings,
        notifications,
        now: () => now,
      );
      await reminders.load();
      final repo = PeriodReminderRepository(
        health,
        reminders,
        notifications,
        settings,
        now: () => now,
      );
      await health.load();
      await repo.refresh();
    }

    test('are scheduled without a factor', () async {
      await start(history());
      expect(notifications.scheduled, isNotEmpty);
    });

    test('are not scheduled while a factor is in force', () async {
      await start(history(factors: [pregnant]));
      expect(notifications.scheduled, isEmpty);
    });
  });
}
