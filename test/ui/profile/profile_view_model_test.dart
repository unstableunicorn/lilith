import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_profile.dart';
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
        conditions: {ReproductiveCondition.pcos},
        treatments: {FertilityTreatment.contraceptive},
        notes: 'Iron tablets since March',
      ),
    );
  });

  test('an existing profile is loaded and summarised', () async {
    await repo.apply(
      (d) => d.withProfile(
        HealthProfile(
          conditions: {
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
      profileSummary(HealthProfile(treatments: {FertilityTreatment.ivf})),
      'No conditions, 1 treatment',
    );
  });
}
