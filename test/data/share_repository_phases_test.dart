import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
import 'package:lilith/domain/temperature_reading.dart';

import '../fakes/fake_pod_service.dart';
import '../fakes/fake_settings_store.dart';
import '../fakes/fake_share_service.dart';

void main() {
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const codec = HealthDocumentCodec();
  const cipher = ShareCipher();
  DateTime june(int d) => DateTime(2026, 6, d);
  final stored = HealthData.empty
      .withPeriod(
        PeriodEvent(
          startDate: DateTime(2026, 5, 4),
          endDate: DateTime(2026, 5, 8),
          flow: FlowIntensity.heavy,
        ),
      )
      .withPeriod(PeriodEvent(startDate: june(1), endDate: june(5)))
      .withReading(TemperatureReading(date: june(2), celsius: 36.3));

  late FakePodService pod;
  late FakeShareService shares;
  late HealthRepository health;
  late PageSettingsRepository pages;
  late ShareRepository repo;
  late DateTime now;

  Future<void> setUpWith(DataProtection protection) async {
    now = june(10);
    pod = FakePodService();
    health = HealthRepository(pod, protection: protection);
    pod.documents[health.documentPath] = codec.encode(stored);
    shares = FakeShareService();
    pages = PageSettingsRepository(FakeSettingsStore());
    repo = ShareRepository(
      health,
      shares,
      protection: protection,
      random: Random(1),
      now: () => now,
      pageSettings: pages,
    );
    await health.load();
  }

  Future<Share> sharePhases() async => (await repo.create(
    recipientWebId: wife,
    label: 'Partner',
    duration: ShareDuration.untilRevoked,
    today: now,
    content: ShareContent.phases,
    includeNotes: true,
    includeContraception: true,
  ))!;

  Map<String, dynamic> copyOf(Share share) {
    final raw = shares.folders['shares/${share.id}']!;
    final json = share.code == null
        ? raw
        : cipher.decrypt(raw, ShareKey.fromCode(share.code!)!);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  group('encrypted data', () {
    setUp(() => setUpWith(DataProtection.encrypted));

    test('the copy is the phases only, under the share key', () async {
      final share = await sharePhases();
      expect(share.isEncrypted, isTrue);
      expect(shares.folders['shares/${share.id}']!.split('.'), hasLength(5));
      final json = copyOf(share);
      expect(isPhasesJson(json), isTrue);
      expect(json.containsKey('readings'), isFalse);
      expect(
        SharedPhases.fromJson(json),
        sharedPhases(
          health.data,
          today: now,
          fertileWindowMode: FertileWindowMode.hidden,
        ),
      );
    });

    test('the share never asks for notes or contraception', () async {
      final share = await sharePhases();
      expect(share.includeNotes, isFalse);
      expect(share.includeContraception, isFalse);
    });

    test('a profile change rewrites the copy', () async {
      final share = await sharePhases();
      shares.calls.clear();
      await health.apply(
        (d) => d.withProfile(HealthProfile(usualPeriodLength: 3)),
      );
      expect(shares.calls, ['write shares/${share.id}']);
    });

    test('turning the fertile window on rewrites the copy', () async {
      final share = await sharePhases();
      shares.calls.clear();
      await pages.update(const PageSettings(showFertileWindow: true));
      expect(shares.calls, ['write shares/${share.id}']);
      expect(copyOf(share)['fertileMode'], 'information');
      shares.calls.clear();
      await pages.update(
        const PageSettings(showFertileWindow: true, showFact: false),
      );
      expect(shares.calls, isEmpty);
    });

    test('sweep brings the copy up to the day', () async {
      final share = await sharePhases();
      now = june(12);
      shares.calls.clear();
      await repo.sweep(now);
      expect(shares.calls, ['write shares/${share.id}']);
      expect(copyOf(share)['updatedOn'], june(12).toIso8601String());
    });

    test('an app-view share is still a health document', () async {
      final share = (await repo.create(
        recipientWebId: wife,
        label: 'A',
        duration: ShareDuration.untilRevoked,
        today: now,
      ))!;
      final raw = cipher.decrypt(
        shares.folders['shares/${share.id}']!,
        ShareKey.fromCode(share.code!)!,
      );
      expect(codec.decode(raw).readings, hasLength(1));
      shares.calls.clear();
      await repo.sweep(now);
      expect(shares.calls, isEmpty);
    });
  });

  group('plain data', () {
    setUp(() => setUpWith(DataProtection.plain));

    test('the copy is plain phases JSON', () async {
      final share = await sharePhases();
      expect(share.code, isNull);
      expect(isPhasesJson(copyOf(share)), isTrue);
    });
  });
}
