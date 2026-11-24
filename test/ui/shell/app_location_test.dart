import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/shell/app_location.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';

void main() {
  final cases = <(String, String, AppLocation)>[
    ('a tab', '/history', const AppLocation(ShellTab.history)),
    ('a page on a tab', '/log/2', const AppLocation(ShellTab.log, pages: 2)),
    ('the root', '/', const AppLocation(ShellTab.today)),
    ('an unknown tab', '/nope/1', const AppLocation(ShellTab.today)),
    (
      'a page count that is not a number',
      '/pod/x',
      const AppLocation(ShellTab.pod),
    ),
    ('a negative page count', '/pod/-1', const AppLocation(ShellTab.pod)),
  ];
  for (final (name, path, want) in cases) {
    test('reads $name', () {
      expect(AppLocation.fromUri(Uri.parse(path)), want);
    });
  }

  test('writes a tab, and its open pages only when there are any', () {
    expect(const AppLocation(ShellTab.relief).uri, Uri.parse('/relief'));
    expect(
      const AppLocation(ShellTab.relief, pages: 1).uri,
      Uri.parse('/relief/1'),
    );
  });

  test('reads back what it writes', () {
    for (final tab in ShellTab.values) {
      for (final pages in [0, 1, 3]) {
        final location = AppLocation(tab, pages: pages);
        expect(AppLocation.fromUri(location.uri), location);
      }
    }
  });
}
