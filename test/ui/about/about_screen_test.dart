import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/about/about_screen.dart';
import 'package:lilith/ui/about/app_version.dart';
import 'package:lilith/ui/core/app_links.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  late RecordingUrlOpener urls;

  Future<void> pump(WidgetTester tester, AppVersion version) async {
    urls = RecordingUrlOpener();
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        openUrl: urls.call,
        child: AboutScreen(version: version),
      ),
    );
    await tester.pumpAndSettle();
  }

  const released = AppVersion(
    name: '0.2.0',
    build: '57',
    commit: '479b45f0123456789abcdef0123456789abcdef0',
  );

  test('the version name is the one in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = RegExp(r'^version: (\S+)\+', multiLine: true);
    expect(AppVersion.current.name, line.firstMatch(pubspec)?.group(1));
  });

  test('a build made outside the deploy says so', () {
    expect(const AppVersion(name: '9.9.9').isLocal, isTrue);
    expect(released.isLocal, isFalse);
  });

  testWidgets('shows the version, build and commit, accessibly', (
    tester,
  ) async {
    await pump(tester, released);
    expect(find.byKey(AboutKeys.version), findsOneWidget);
    expect(find.textContaining('0.2.0'), findsWidgets);
    expect(find.textContaining('57'), findsWidgets);
    expect(find.textContaining('479b45f'), findsWidgets);
    expect(find.byKey(AboutKeys.local), findsNothing);
    await expectAccessible(tester);
  });

  testWidgets('a local build shows no build number or commit', (tester) async {
    await pump(tester, const AppVersion(name: '9.9.9'));
    expect(find.byKey(AboutKeys.local), findsOneWidget);
    expect(find.byKey(AboutKeys.commit), findsNothing);
  });

  testWidgets('links the commit, the latest build and the source', (
    tester,
  ) async {
    await pump(tester, released);
    for (final key in [AboutKeys.commit, AboutKeys.latest, AboutKeys.source]) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }
    expect(urls.opened, [
      Uri.parse(
        'https://github.com/unstableunicorn/lilith/commit/${released.commit}',
      ),
      AppLinks.latestBuild,
      AppLinks.source,
    ]);
  });
}
