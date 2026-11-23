import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/shopping_item.dart';

void main() {
  group('ShoppingItem', () {
    const item = ShoppingItem(
      name: 'Heat pack',
      note: 'for cramps',
      symptomKey: 'cramps',
    );

    test('starts unbought', () {
      expect(item.bought, isFalse);
    });

    test('copyWith toggles bought and keeps the rest', () {
      final bought = item.copyWith(bought: true);
      expect(bought.bought, isTrue);
      expect(bought.name, item.name);
      expect(bought.note, item.note);
      expect(bought.symptomKey, item.symptomKey);
    });

    test('is equal by value', () {
      const same = ShoppingItem(
        name: 'Heat pack',
        note: 'for cramps',
        symptomKey: 'cramps',
      );
      expect(item, same);
      expect(item.hashCode, same.hashCode);
      expect(item, isNot(item.copyWith(bought: true)));
    });

    test('round-trips through JSON', () {
      expect(ShoppingItem.fromJson(item.toJson()), item);
      const bare = ShoppingItem(name: 'Ginger tea', bought: true);
      expect(ShoppingItem.fromJson(bare.toJson()), bare);
    });

    test('omits absent note and symptom keys', () {
      const bare = ShoppingItem(name: 'Ginger tea');
      final json = bare.toJson();
      expect(json.keys, unorderedEquals(['name', 'bought']));
    });

    test('reads the document shape the original app wrote', () {
      final got = ShoppingItem.fromJson(const {
        'name': 'Heat pack',
        'note': 'for cramps',
        'symptom': 'cramps',
        'bought': false,
      });
      expect(got, item);
      expect(ShoppingItem.fromJson(const {'name': 'Tea'}).bought, isFalse);
    });
  });
}
