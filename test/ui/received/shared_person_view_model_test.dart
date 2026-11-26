import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/received/shared_person_view_model.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_share_reader.dart';

void main() {
  const me = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  final ownerRoot = Uri.parse(
    'https://solid.unstableunicorn.dev/unstableunicorn/',
  );
  const codec = HealthDocumentCodec();
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);
  final today = DateTime(2026, 6, 10);
  final share = ReceivedShare(
    sharerWebId: owner,
    label: 'Elric',
    addedOn: today,
  );
  final theirs = HealthData.empty
      .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 15)))
      .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 13)))
      .withReading(
        TemperatureReading(date: DateTime(2026, 6, 9), celsius: 36.7),
      )
      .withDailyLog(
        DailyLog(date: DateTime(2026, 6, 8), symptoms: const {Symptom.cramps}),
      );

  late FakeShareReader reader;
  late ReceivedShareRepository repo;
  late SharedPersonViewModel vm;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    reader.documents[copyUrl] = codec.encode(theirs);
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
    vm = SharedPersonViewModel(repo, share, now: () => today);
  });

  test('is loading until refreshed, then has their data', () async {
    expect(vm.isLoading, isTrue);
    expect(vm.data, isNull);
    expect(vm.prediction, isNull);
    expect(vm.nextPeriodText, isNull);
    await vm.refresh();
    expect(vm.isLoading, isFalse);
    expect(vm.hasData, isTrue);
    expect(vm.data, theirs);
  });

  test('predicts and lists from their data, newest first', () async {
    await vm.refresh();
    expect(vm.prediction!.currentCycleDay, 29);
    expect(vm.nextPeriodText, 'Period expected today');
    expect(vm.latestReading!.celsius, 36.7);
    expect(vm.cycles.map((c) => c.start), [
      DateTime(2026, 5, 13),
      DateTime(2026, 4, 15),
    ]);
    expect(vm.cycles.first.length, isNull);
    expect(vm.cycles.last.length, 28);
    expect(vm.days.single.date, DateTime(2026, 6, 8));
    expect(vm.chartReadings, hasLength(1));
    expect(vm.periodStarts, hasLength(2));
  });

  test('phrases the days until the next period', () async {
    await vm.refresh();
    final later = SharedPersonViewModel(
      repo,
      share,
      now: () => DateTime(2026, 6, 6),
    );
    expect(later.nextPeriodText, 'Period expected in 4 days, around 10 Jun');
    final after = SharedPersonViewModel(
      repo,
      share,
      now: () => DateTime(2026, 6, 12),
    );
    expect(after.nextPeriodText, 'Period was expected 2 days ago, on 10 Jun');
  });

  test('an ended share has no data', () async {
    reader.documents.clear();
    await vm.refresh();
    expect(vm.view, isA<SharedViewFailed>());
    expect(vm.hasData, isFalse);
    expect(vm.cycles, isEmpty);
    expect(vm.days, isEmpty);
  });

  test('without their contraception there are no dose lines', () async {
    await vm.refresh();
    final day = DateTime(2026, 6, 8);
    expect(vm.doseText(day), isNull);
    expect(vm.summaryLine(vm.days.single), isNotNull);
  });

  test('with their contraception: dose lines and missed days', () async {
    DateTime june(int d, [int h = 0]) => DateTime(2026, 6, d, h);
    reader.documents[copyUrl] = codec.encode(
      theirs
          .withProfile(
            HealthProfile(
              contraception: Contraception.combinedPill,
              contraceptionSchedule: ContraceptionSchedule(
                form: DoseForm.pill,
                start: june(6),
                daysOn: 21,
                daysOff: 7,
                windowHours: 3,
              ),
            ),
          )
          .withDailyLog(
            DailyLog(date: june(6), contraceptionDoneAt: june(6, 9)),
          ),
    );
    await vm.refresh();
    expect(vm.days.map((l) => l.date), [june(9), june(8), june(7), june(6)]);
    expect(vm.doseText(june(6)), contains('09:00'));
    expect(vm.doseText(june(7)), isNotNull);
    expect(vm.doseText(june(10)), isNull);
    expect(vm.summaryLine(vm.days.last), isNull);
    expect(vm.summaryLine(vm.days[1]), isNotNull);
  });
}
