import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../harness.dart';

void main() {
  temperatureChartTests();
  for (final brightness in Brightness.values) {
    group('in the ${brightness.name} theme', () {
      Future<void> pump(WidgetTester tester, Widget page) async {
        await tester.pumpWidget(
          MaterialApp(theme: lilithTheme(brightness), home: page),
        );
        // The wait indicator spins forever, so the page can never settle.
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('a page shows its title, actions and content', (
        tester,
      ) async {
        var tapped = 0;
        await pump(
          tester,
          PageScaffold(
            title: 'Lilith',
            actions: [
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout),
                onPressed: () => tapped++,
              ),
            ],
            children: const [
              SectionHeading('Flow'),
              AppCard(
                icon: Icons.favorite,
                title: 'Next period',
                child: Text('In 12 days'),
              ),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.calendar_today,
                      label: 'Cycle day',
                      value: '14',
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      icon: Icons.thermostat,
                      label: 'Latest temp',
                      value: '—',
                    ),
                  ),
                ],
              ),
              ProblemText('Too short.'),
              BusyIndicator(),
            ],
          ),
        );
        for (final text in [
          'Lilith',
          'Flow',
          'Next period',
          'In 12 days',
          'Cycle day',
          '14',
          'Latest temp',
          '—',
          'Too short.',
        ]) {
          expect(find.text(text), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Log out'));
        expect(tapped, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await expectAccessible(tester);
      });

      testWidgets('a notice can carry detail and be dismissed', (tester) async {
        var dismissed = 0;
        await pump(
          tester,
          Scaffold(
            body: Column(
              children: [
                NoticeBanner(
                  message: 'Could not save.',
                  detail: 'HTTP 503',
                  dismissKey: const Key('ok'),
                  onDismiss: () => dismissed++,
                ),
              ],
            ),
          ),
        );
        expect(find.text('Could not save.'), findsOneWidget);
        expect(find.text('HTTP 503'), findsOneWidget);
        await tester.tap(find.byKey(const Key('ok')));
        expect(dismissed, 1);
        await expectAccessible(tester);
      });
    });
  }
}

void temperatureChartTests() {
  testWidgets('the chart describes itself in words and reads accessibly', (
    tester,
  ) async {
    final readings = [
      for (var i = 0; i < 10; i++)
        TemperatureReading(
          date: DateTime(2026, 6, 1 + i),
          celsius: 36.0 + i / 10,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: lilithTheme(Brightness.light),
        home: Scaffold(
          body: TemperatureChart(
            readings: readings,
            periodStarts: {DateTime(2026, 6, 3)},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'10 temperature readings.*36\.0.*36\.9')),
      findsOneWidget,
    );
    await expectAccessible(tester);
  });

  testWidgets('with one reading the chart still draws', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lilithTheme(Brightness.light),
        home: Scaffold(
          body: TemperatureChart(
            readings: [
              TemperatureReading(date: DateTime(2026, 6, 1), celsius: 36.4),
            ],
            periodStarts: const {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TemperatureChart), findsOneWidget);
  });
}
