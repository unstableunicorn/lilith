import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/home/home_view_model.dart';
import 'package:lilith/ui/profile/profile_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  late HealthRepository repo;
  late ProfileViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = ProfileViewModel(repo);
  });

  test('starts from the stored profile, empty and clean', () {
    expect(vm.conditions, isEmpty);
    expect(vm.treatments, isEmpty);
    expect(vm.notes, '');
    expect(vm.isDirty, isFalse);
  });

  test('toggling and typing make it dirty; save writes and cleans', () async {
    vm.toggleCondition(ReproductiveCondition.pcos);
    vm.toggleTreatment(FertilityTreatment.contraceptive);
    vm.toggleTreatment(FertilityTreatment.ivf);
    vm.toggleTreatment(FertilityTreatment.ivf);
    vm.setNotes('  Iron tablets since March  ');
    expect(vm.isDirty, isTrue);
    await vm.save();
    expect(vm.isDirty, isFalse);
    expect(
      repo.data.profile,
      HealthProfile(
        conditions: const {ReproductiveCondition.pcos},
        treatments: const {FertilityTreatment.contraceptive},
        notes: 'Iron tablets since March',
      ),
    );
  });

  test('an existing profile is loaded and summarised', () async {
    await repo.apply(
      (d) => d.withProfile(
        HealthProfile(
          conditions: const {
            ReproductiveCondition.endometriosis,
            ReproductiveCondition.pmdd,
          },
          notes: 'x',
        ),
      ),
    );
    vm = ProfileViewModel(repo);
    expect(vm.conditions, {
      ReproductiveCondition.endometriosis,
      ReproductiveCondition.pmdd,
    });
    expect(
      profileSummary(repo.data.profile),
      '2 conditions, no treatments, notes',
    );
    expect(profileSummary(HealthProfile()), 'Nothing recorded yet');
    expect(
      profileSummary(HealthProfile(treatments: const {FertilityTreatment.ivf})),
      'No conditions, 1 treatment',
    );
  });

  test('history fields are set, cleared and summarised', () async {
    vm.setContraception(Contraception.combinedPill);
    vm.setRegularity(CycleRegularity.irregular);
    vm.setBirthYear('1990');
    vm.setHistory('pregnancies', '2');
    vm.setHistory('births', '1');
    expect(vm.isDirty, isTrue);
    await vm.save();
    final p = repo.data.profile;
    expect(p.contraception, Contraception.combinedPill);
    expect(p.regularity, CycleRegularity.irregular);
    expect(p.birthYear, 1990);
    expect(p.history, const ObstetricHistory(pregnancies: 2, births: 1));
    expect(profileSummary(p), 'No conditions, no treatments, history');
    vm.setContraception(Contraception.combinedPill);
    vm.setBirthYear('');
    vm.setHistory('births', '');
    await vm.save();
    expect(repo.data.profile.contraception, isNull);
    expect(repo.data.profile.birthYear, isNull);
    expect(repo.data.profile.history, const ObstetricHistory(pregnancies: 2));
  });

  test('the prediction explanation notes suppressed temperature', () {
    const p = CyclePrediction(
      method: PredictionMethod.cycleAverage,
      confidence: PredictionConfidence.low,
      shiftSuppressed: true,
    );
    final home = HomeViewModel(repo, now: DateTime.now);
    expect(home.howText(p), contains('hormonal contraception'));
    expect(
      confidenceCapFor(CycleRegularity.irregular),
      PredictionConfidence.low,
    );
    expect(
      confidenceCapFor(CycleRegularity.somewhatIrregular),
      PredictionConfidence.medium,
    );
    expect(confidenceCapFor(null), isNull);
  });
}
