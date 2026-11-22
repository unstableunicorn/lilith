import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/solid_client.dart';

void main() {
  test('the app folder on the pod is named after the package', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final name = pubspec
        .firstWhere((l) => l.startsWith('name:'))
        .split(':')
        .last
        .trim();
    expect(SolidClient.appDirName, name);
    expect(SolidClient.appDirName, isNotEmpty);
    expect(SolidClient.appDirName, isNot(contains('/')));
  });
}
