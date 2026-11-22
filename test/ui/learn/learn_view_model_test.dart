import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/period_facts.dart';
import 'package:lilith/ui/learn/learn_view_model.dart';

void main() {
  late LearnViewModel vm;

  setUp(() => vm = LearnViewModel());

  test('offers every fact and no answer until asked', () {
    expect(vm.facts, periodFacts);
    expect(vm.facts, hasLength(14));
    expect(vm.asked, isFalse);
    expect(vm.answer, isNull);
  });

  test('a question with a known keyword finds the best entry', () {
    final entry = knowledgeBase.first;
    vm.ask('Tell me about ${entry.keywords.first}');
    expect(vm.asked, isTrue);
    expect(vm.answer, entry);
  });

  test(
    'a question nothing matches has no answer, and asking is remembered',
    () {
      vm.ask('zzqx');
      expect(vm.asked, isTrue);
      expect(vm.answer, isNull);
      vm.ask('   ');
      expect(vm.asked, isFalse, reason: 'a blank question is not a question');
    },
  );

  test('the fact of the day turns with the day of the year', () {
    final jan1 = factOfTheDay(DateTime(2026, 1, 1));
    final jan2 = factOfTheDay(DateTime(2026, 1, 2));
    expect(jan1, periodFacts[0]);
    expect(jan2, periodFacts[1]);
    expect(
      factOfTheDay(DateTime(2026, 1, 1 + periodFacts.length)),
      periodFacts[0],
    );
  });
}
