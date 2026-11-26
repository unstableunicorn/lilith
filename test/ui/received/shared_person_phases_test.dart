import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/fertile_window.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shared_phases.dart';
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
  final copyUrl = SharePlan.forRecipient(me).documentUrl(ownerRoot);
  DateTime june(int d) => DateTime(2026, 6, d);
  final today = june(10);
  final share = ReceivedShare(
    sharerWebId: owner,
    label: 'Elric',
    addedOn: today,
  );
  final window = FertileWindow(
    start: june(10),
    end: june(15),
    basis: FertileWindowBasis.shift,
  );

  late FakeShareReader reader;
  late ReceivedShareRepository repo;

  setUp(() async {
    final health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    reader = FakeShareReader()..roots[owner] = ownerRoot;
    repo = ReceivedShareRepository(health, reader, ownWebId: me);
  });

  Future<SharedPersonViewModel> open(SharedPhases phases) async {
    reader.documents[copyUrl] = jsonEncode(phases.toJson());
    final vm = SharedPersonViewModel(repo, share, now: () => today);
    await vm.refresh();
    return vm;
  }

  test('a phases share has phases, no health data', () async {
    final vm = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
        nextPeriod: june(29),
      ),
    );
    expect(vm.phases, isNotNull);
    expect(vm.data, isNull);
    expect(vm.hasData, isTrue);
    expect(vm.days, isEmpty);
    expect(vm.cycles, isEmpty);
    expect(vm.chartReadings, isEmpty);
  });

  test('says the next period, the cycle day and when it was written', () async {
    final vm = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
        nextPeriod: june(14),
      ),
    );
    expect(vm.nextPeriodText, 'Period expected in 4 days, around 14 Jun');
    expect(vm.phasesCycleLine, contains('10'));
    expect(vm.phasesUpdatedText, contains('8 Jun'));
  });

  test('with nothing shared yet it has no data', () async {
    final vm = await open(SharedPhases(updatedOn: june(8)));
    expect(vm.hasData, isFalse);
    expect(vm.nextPeriodText, isNull);
    expect(vm.phasesCycleLine, isNull);
  });

  test('the calendar marks their month and moves', () async {
    final vm = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1), endDate: june(4))],
        nextPeriod: june(29),
        ovulation: june(14),
      ),
    );
    expect(vm.phasesDays, hasLength(30));
    expect(vm.phasesDays.where((d) => d.inPeriod), hasLength(4));
    expect(vm.phasesDays.singleWhere((d) => d.ovulation).date, june(14));
    vm.nextMonth();
    expect(vm.month, DateTime(2026, 7));
    expect(vm.phasesDays, hasLength(31));
    vm
      ..previousMonth()
      ..previousMonth();
    expect(vm.month, DateTime(2026, 5));
  });

  test('the disclaimer follows what is shown', () async {
    final plain = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1))],
      ),
    );
    expect(plain.phasesDisclaimer, isNull);
    final ovulation = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1))],
        ovulation: june(14),
      ),
    );
    expect(ovulation.phasesDisclaimer, estimateDisclaimer);
    final informed = await open(
      SharedPhases(
        updatedOn: june(8),
        periods: [PeriodEvent(startDate: june(1))],
        ovulation: june(14),
        fertileWindow: window,
        fertileMode: FertileWindowMode.information,
      ),
    );
    expect(
      informed.phasesDisclaimer,
      fertileWindowDisclaimer(FertileWindowMode.information),
    );
  });
}
