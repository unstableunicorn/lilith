import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/home/home_view_model.dart';

import '../../fakes/fake_pod_service.dart';

/// Today's view model while a life factor holds the prediction.
void main() {
  final today = DateTime(2026, 6, 10, 9, 30);
  late HealthRepository repo;
  late HomeViewModel vm;

  Future<void> seed({List<LifeFactor> factors = const []}) async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    await repo.apply((d) {
      var next = d.withProfile(HealthProfile(lifeFactors: factors));
      for (final start in [
        DateTime(2026, 3, 18),
        DateTime(2026, 4, 15),
        DateTime(2026, 5, 13),
      ]) {
        next = next.withPeriod(PeriodEvent(startDate: start));
        // The same mood at the same point of each cycle, and a positive
        // test in the current one.
        next = next.withDailyLog(
          DailyLog(
            date: addDays(start, 28),
            signs: BodySigns(moods: const {Mood.irritable}),
            ovulationTest: start == DateTime(2026, 5, 13)
                ? OvulationTest.positive
                : null,
          ),
        );
      }
      return next;
    });
    vm = HomeViewModel(repo, now: () => today);
  }

  final pregnant = LifeFactor(
    kind: LifeFactorKind.pregnant,
    start: DateTime(2026, 5, 20),
  );

  test('without a factor Today predicts as before', () async {
    await seed();
    expect(vm.prediction.method, PredictionMethod.cycleAverage);
    expect(vm.daysUntilNextPeriod, 0);
    expect(vm.cycleLine, isNotNull);
    expect(vm.forecast.hasData, isTrue);
    expect(vm.fertileWindowShown(FertileWindowMode.information), isNotNull);
  });

  test('under a factor it says why, with no countdown, cycle day, fertile '
      'window or forecast', () async {
    await seed(factors: [pregnant]);
    expect(vm.prediction.method, PredictionMethod.paused);
    expect(
      vm.howText(vm.prediction),
      'Predictions are paused while you are pregnant.',
    );
    expect(vm.daysUntilNextPeriod, isNull);
    expect(vm.cycleLine, isNull);
    expect(vm.fertileWindowShown(FertileWindowMode.information), isNull);
    expect(vm.forecast.hasData, isFalse);
  });

  test('after the factor ends it waits for a period', () async {
    await seed(factors: [pregnant.endedOn(DateTime(2026, 6, 1))]);
    expect(vm.prediction.method, PredictionMethod.awaitingPeriod);
    expect(
      vm.howText(vm.prediction),
      'Predictions start again when you log your next period.',
    );
    expect(vm.daysUntilNextPeriod, isNull);
    expect(vm.forecast.hasData, isFalse);
  });

  test('breastfeeding pauses nothing on Today', () async {
    await seed(
      factors: [
        LifeFactor(
          kind: LifeFactorKind.breastfeeding,
          start: DateTime(2026, 5, 20),
        ),
      ],
    );
    expect(vm.prediction.method, PredictionMethod.cycleAverage);
    expect(vm.prediction.isOnHold, isFalse);
    expect(vm.daysUntilNextPeriod, isNotNull);
  });
}
