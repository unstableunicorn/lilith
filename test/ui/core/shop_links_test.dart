import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/core/shop_links.dart';

void main() {
  test('nearby is a maps search for the item near me', () {
    expect(
      mapsNearMe('Heat pad / hot water bottle').toString(),
      'https://www.google.com/maps/search/Heat%20pad%20%2F%20hot%20water%20bottle%20near%20me',
    );
  });

  test('online is a shopping search for buying the item', () {
    final uri = retailerSearch('Ginger tea');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters, {'q': 'buy Ginger tea', 'tbm': 'shop'});
  });
}
