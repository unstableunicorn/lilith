import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/ui/shopping/shopping_view_model.dart';

import '../../fakes/fake_pod_service.dart';

void main() {
  late HealthRepository repo;
  late ShoppingViewModel vm;

  setUp(() async {
    repo = HealthRepository(FakePodService(), protection: DataProtection.plain);
    await repo.load();
    vm = ShoppingViewModel(repo);
  });

  test('starts empty', () {
    expect(vm.items, isEmpty);
    expect(vm.isEmpty, isTrue);
    expect(vm.toBuy, 0);
  });

  test('adds a trimmed item once, refusing blanks and duplicates', () async {
    expect(await vm.add('  Heat pad '), isTrue);
    expect(await vm.add('heat pad'), isFalse);
    expect(await vm.add('   '), isFalse);
    expect(vm.items.map((i) => i.name), ['Heat pad']);
    expect(vm.toBuy, 1);
  });

  test('ticking off moves an item to the bottom and back', () async {
    await repo.apply(
      (d) => d
          .withShoppingItem(const ShoppingItem(name: 'A', note: 'For Cramps'))
          .withShoppingItem(const ShoppingItem(name: 'B')),
    );
    await vm.toggle('A');
    expect(vm.items.map((i) => i.name), ['B', 'A']);
    expect(vm.items.last.bought, isTrue);
    expect(vm.toBuy, 1);
    await vm.toggle('A');
    expect(vm.items.every((i) => !i.bought), isTrue);
    expect(vm.toBuy, 2);
  });

  test('removes an item', () async {
    await vm.add('A');
    await vm.remove('A');
    expect(vm.isEmpty, isTrue);
  });
}
