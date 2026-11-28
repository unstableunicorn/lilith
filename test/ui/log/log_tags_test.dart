import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/tags.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:lilith/ui/log/log_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

/// A person's own tags on the Log tab.
void main() {
  final now = DateTime(2026, 6, 10, 9, 30);
  final day = DateTime(2026, 6, 10);
  late HealthRepository health;

  DailyLog past(int d, List<String> tags) => DailyLog(
    date: DateTime(2026, 6, d),
    signs: BodySigns(tags: tags),
  );

  setUp(() async {
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await health.load();
    await health.apply(
      (d) => d
          .withDailyLog(past(1, ['Travel', 'alcohol']))
          .withDailyLog(past(2, ['Travel']))
          .withDailyLog(past(3, ['night shift'])),
    );
  });

  group('LogViewModel', () {
    late LogViewModel vm;

    setUp(() => vm = LogViewModel(health, now: () => now));

    test('the Tags group shows from the start', () {
      expect(vm.shows(LogGroup.tags), isTrue);
    });

    test('a day starts with no tags and offers the past ones', () {
      expect(vm.signs.tags, isEmpty);
      expect(vm.tagSuggestions(''), ['Travel', 'alcohol', 'night shift']);
      expect(vm.isDirty, isFalse);
    });

    test('adding a tag puts it on the day and takes it off the offer', () {
      var told = 0;
      vm
        ..addListener(() => told++)
        ..addTag('  yoga ');
      expect(vm.signs.tags, ['yoga']);
      expect(vm.isDirty, isTrue);
      expect(told, 1);
      vm.addTag('alcohol');
      expect(vm.signs.tags, ['alcohol', 'yoga']);
      expect(vm.tagSuggestions(''), ['Travel', 'night shift']);
    });

    test('a tag typed in another case takes the spelling used before', () {
      vm.addTag('TRAVEL');
      expect(vm.signs.tags, ['Travel']);
    });

    test('a blank adds nothing and tells nobody', () {
      var told = 0;
      vm
        ..addListener(() => told++)
        ..addTag('   ');
      expect(vm.signs.tags, isEmpty);
      expect(vm.isDirty, isFalse);
      expect(told, 0);
    });

    test('removing a tag takes it off the day and offers it again', () {
      vm
        ..addTag('Travel')
        ..addTag('yoga')
        ..removeTag('Travel');
      expect(vm.signs.tags, ['yoga']);
      expect(vm.tagSuggestions(''), contains('Travel'));
    });

    test('typing narrows the offer', () {
      expect(vm.tagSuggestions('ni'), ['night shift']);
      expect(vm.tagSuggestions('zzz'), isEmpty);
    });

    test("a day's own tags are not offered to it, other days' are", () {
      vm.pickDate(DateTime(2026, 6, 3));
      expect(vm.signs.tags, ['night shift']);
      expect(vm.tagSuggestions(''), ['Travel', 'alcohol']);
    });

    test('saving stores the tags with the day, and they load back', () async {
      vm
        ..addTag('yoga')
        ..toggleMood(Mood.calm);
      await vm.save();
      expect(
        health.data.logFor(day),
        DailyLog(
          date: day,
          signs: BodySigns(moods: const {Mood.calm}, tags: const ['yoga']),
        ),
      );
      final again = LogViewModel(health, now: () => now);
      expect(again.signs.tags, ['yoga']);
      expect(again.isSavedAsIs, isTrue);
    });

    test(
      'with the group off, it still shows on a day that holds a tag',
      () async {
        await health.apply((d) => d.withLogGroup(LogGroup.tags, shown: false));
        expect(vm.shows(LogGroup.tags), isFalse);
        vm.pickDate(DateTime(2026, 6, 3));
        expect(vm.shows(LogGroup.tags), isTrue);
      },
    );
  });

  group('LogScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          session: SessionRepository(
            FakePodSessionService(),
            FakeSettingsStore(),
          ),
          health: health,
          child: LogScreen(now: () => now),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool selected(WidgetTester tester, String tag) =>
        tester.widget<FilterChip>(find.byKey(LogKeys.tag(tag))).selected;

    Future<void> tapOn(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('has a Tags section with a field and the past tags as '
        'chips, none chosen', (tester) async {
      await pump(tester);
      expect(find.byKey(LogKeys.group(LogGroup.tags)), findsOneWidget);
      expect(find.byKey(LogKeys.tagField), findsOneWidget);
      expect(find.byKey(LogKeys.addTag), findsOneWidget);
      for (final t in ['Travel', 'alcohol', 'night shift']) {
        expect(selected(tester, t), isFalse, reason: t);
      }
      await expectAccessible(tester);
    });

    testWidgets('the field takes no more than a tag can hold', (tester) async {
      await pump(tester);
      expect(
        tester.widget<TextField>(find.byKey(LogKeys.tagField)).maxLength,
        maxTagLength,
      );
    });

    testWidgets('tapping a past tag chooses it; tapping again takes it off', (
      tester,
    ) async {
      await pump(tester);
      await tapOn(tester, LogKeys.tag('Travel'));
      expect(selected(tester, 'Travel'), isTrue);
      expect(selected(tester, 'alcohol'), isFalse);
      await tapOn(tester, LogKeys.tag('Travel'));
      expect(selected(tester, 'Travel'), isFalse);
    });

    testWidgets('typing a new tag and tapping Add puts it on the day and '
        'empties the field', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.byKey(LogKeys.tagField));
      await tester.enterText(find.byKey(LogKeys.tagField), 'yoga');
      await tester.pumpAndSettle();
      await tapOn(tester, LogKeys.addTag);
      expect(selected(tester, 'yoga'), isTrue);
      expect(
        tester.widget<TextField>(find.byKey(LogKeys.tagField)).controller!.text,
        isEmpty,
      );
      await expectAccessible(tester);
    });

    testWidgets("the keyboard's done key adds the tag too", (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.byKey(LogKeys.tagField));
      await tester.enterText(find.byKey(LogKeys.tagField), 'yoga');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(selected(tester, 'yoga'), isTrue);
    });

    testWidgets('typing narrows the past tags offered', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.byKey(LogKeys.tagField));
      await tester.enterText(find.byKey(LogKeys.tagField), 'ni');
      await tester.pumpAndSettle();
      expect(find.byKey(LogKeys.tag('night shift')), findsOneWidget);
      expect(find.byKey(LogKeys.tag('Travel')), findsNothing);
    });

    testWidgets('a chosen tag stays in view while typing something else', (
      tester,
    ) async {
      await pump(tester);
      await tapOn(tester, LogKeys.tag('Travel'));
      await tester.enterText(find.byKey(LogKeys.tagField), 'ni');
      await tester.pumpAndSettle();
      expect(selected(tester, 'Travel'), isTrue);
    });

    testWidgets('saving stores the tags', (tester) async {
      await pump(tester);
      await tapOn(tester, LogKeys.tag('alcohol'));
      await tester.enterText(find.byKey(LogKeys.tagField), 'yoga');
      await tester.pumpAndSettle();
      await tapOn(tester, LogKeys.addTag);
      await tapOn(tester, LogKeys.save);
      expect(health.data.logFor(day)!.signs.tags, ['alcohol', 'yoga']);
    });

    testWidgets('with the group turned off there is no Tags section', (
      tester,
    ) async {
      await health.apply((d) => d.withLogGroup(LogGroup.tags, shown: false));
      await pump(tester);
      expect(find.byKey(LogKeys.group(LogGroup.tags)), findsNothing);
      expect(find.byKey(LogKeys.tagField), findsNothing);
    });
  });
}
