import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/reminders/dose_schedule_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  final today = DateTime(2026, 6, 10);
  late FakePodService pod;
  late HealthRepository repo;

  Future<DoseScheduleViewModel> vm(
    Contraception method, {
    ContraceptionSchedule? existing,
  }) async {
    pod = FakePodService();
    repo = HealthRepository(pod, protection: DataProtection.plain);
    await repo.load();
    await repo.apply(
      (d) => d.copyWith(
        profile: HealthProfile(
          contraception: method,
          contraceptionSchedule: existing,
        ),
      ),
    );
    return DoseScheduleViewModel(repo, now: () => today);
  }

  ContraceptionSchedule? saved() => repo.data.profile.contraceptionSchedule;

  test('the combined pill starts standard, today, with its window', () async {
    final m = await vm(Contraception.combinedPill);
    expect(m.presets, hasLength(1));
    expect(await m.save(), isTrue);
    expect(
      saved(),
      ContraceptionSchedule(
        form: DoseForm.pill,
        start: today,
        daysOn: 21,
        daysOff: 7,
        windowHours: 24,
      ),
    );
  });

  test('choosing a preset takes its form, window and first regimen', () async {
    final m = await vm(Contraception.progestogenOnlyPill)
      ..choosePreset(1);
    expect(m.windowHours, 12);
    expect(m.regimen, Regimen.continuous);
    final ring = await vm(Contraception.patchOrRing)
      ..choosePreset(1);
    await ring.save();
    expect(saved()?.form, DoseForm.ring);
    expect(saved()?.windowHours, 48);
  });

  test('a regimen sets the days; custom keeps what is typed', () async {
    final m = await vm(Contraception.combinedPill)
      ..chooseRegimen(Regimen.tricycling);
    expect((m.daysOn, m.daysOff), (63, 7));
    m
      ..chooseRegimen(null)
      ..setDaysOn(24)
      ..setDaysOff(4);
    expect(m.regimen, isNull);
    await m.save();
    expect((saved()?.daysOn, saved()?.daysOff), (24, 4));
  });

  test('days, window and time stay within their bounds', () async {
    final m = await vm(Contraception.combinedPill)
      ..chooseRegimen(null)
      ..setDaysOn(0)
      ..setDaysOff(-2)
      ..setWindowHours(0);
    expect((m.daysOn, m.daysOff, m.windowHours), (1, 0, 1));
    m.setWindowHours(500);
    expect(m.windowHours, DoseScheduleViewModel.maxWindowHours);
  });

  test('start, time, window and quiet hours are saved', () async {
    final m = await vm(Contraception.combinedPill)
      ..setStart(DateTime(2026, 6, 3))
      ..setTime(hour: 21, minute: 15)
      ..setWindowHours(12)
      ..setQuietHours(true);
    await m.save();
    expect(saved()?.start, DateTime(2026, 6, 3));
    expect((saved()?.hour, saved()?.minute), (21, 15));
    expect(saved()?.windowHours, 12);
    expect(saved()?.quietHours, isTrue);
  });

  test('opens on the schedule already set', () async {
    final existing = ContraceptionSchedule(
      form: DoseForm.ring,
      start: DateTime(2026, 5, 1),
      daysOn: 21,
      daysOff: 0,
      windowHours: 36,
      hour: 20,
    );
    final m = await vm(Contraception.patchOrRing, existing: existing);
    expect(m.presetIndex, 1);
    expect(m.regimen, Regimen.continuous);
    expect(m.windowHours, 36);
    expect(m.start, DateTime(2026, 5, 1));
    expect(m.hour, 20);
  });

  test('a failed save says so and keeps the form', () async {
    final m = await vm(Contraception.combinedPill);
    pod.failWrites = const PodAccessException('403');
    expect(await m.save(), isFalse);
    expect(m.isSaving, isFalse);
  });
}
