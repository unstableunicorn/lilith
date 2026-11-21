import 'package:flutter_test/flutter_test.dart';
import 'package:lillith/main.dart';

void main() {
  testWidgets('the app starts', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(tester.takeException(), isNull);
  });
}
