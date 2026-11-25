import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/dose_presets.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/reminders/dose_schedule_screen.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fake_notification_service.dart';
import '../../fakes/fake_pod_service.dart';
import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';
import '../../harness.dart';

void main() {
  final today = dateOnly(DateTime.now());
  late FakeSettingsStore settings;
  late FakeNotificationService notifications;
  late ReminderRepository reminders;
  late HealthRepository health;

  ContraceptionSchedule continuous() => ContraceptionSchedule(
    form: DoseForm.pill,
    start: addDays(today, -30),
    daysOn: 21,
    daysOff: 0,
    windowHours: 24,
  );

  Future<void> pump(
    WidgetTester tester, {
    Contraception? method = Contraception.combinedPill,
    ContraceptionSchedule? schedule,
    Widget child = const RemindersScreen(),
    RecordingUrlOpener? urls,
  }) async {
    settings = FakeSettingsStore();
    notifications = FakeNotificationService();
    reminders = ReminderRepository(settings, notifications);
    health = HealthRepository(
      FakePodService(),
      protection: DataProtection.plain,
    );
    await tester.runAsync(() async {
      await health.load();
      await health.apply(
        (d) => d.copyWith(
          profile: HealthProfile(
            contraception: method,
            contraceptionSchedule: schedule,
          ),
        ),
      );
    });
    reminders.setDose(method, schedule);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      harness(
        session: SessionRepository(
          FakePodSessionService(),
          FakeSettingsStore(),
        ),
        reminders: reminders,
        health: health,
        openUrl: urls?.call,
        child: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  ContraceptionSchedule? saved() => health.data.profile.contraceptionSchedule;

  group('on Reminders', () {
    testWidgets('shows for a pill, patch or ring, and not otherwise', (
      tester,
    ) async {
      for (final m in Contraception.values) {
        await pump(tester, method: m);
        expect(
          find.byKey(RemindersKeys.dose),
          dosePresetsFor(m).isEmpty ? findsNothing : findsOneWidget,
          reason: '$m',
        );
      }
      await pump(tester);
      await expectAccessible(tester);
    });

    testWidgets('the switch turns them on for this phone', (tester) async {
      await pump(tester, schedule: continuous());
      expect(find.byKey(RemindersKeys.doseToggle), findsOneWidget);
      await tester.tap(find.byKey(RemindersKeys.doseToggle));
      await tester.pumpAndSettle();
      expect(settings.reminder.contraception, isTrue);
    });

    testWidgets('once on, offers exact times until they are allowed', (
      tester,
    ) async {
      await pump(tester, schedule: continuous());
      expect(find.byKey(RemindersKeys.doseExact), findsNothing);
      expect(find.byKey(RemindersKeys.doseToggle), findsOneWidget);
      await tester.tap(find.byKey(RemindersKeys.doseToggle));
      await tester.pumpAndSettle();
      expect(find.byKey(RemindersKeys.doseExact), findsOneWidget);
      await expectAccessible(tester);
      await tester.tap(find.byKey(RemindersKeys.doseExact));
      await tester.pumpAndSettle();
      expect(notifications.exactRequests, 1);
      expect(find.byKey(RemindersKeys.doseExact), findsNothing);
    });

    testWidgets('a break today moves the next dose four days on', (
      tester,
    ) async {
      await pump(tester, schedule: continuous());
      expect(find.byKey(RemindersKeys.doseBreak), findsOneWidget);
      await tester.ensureVisible(find.byKey(RemindersKeys.doseBreak));
      await tester.tap(find.byKey(RemindersKeys.doseBreak));
      await tester.pumpAndSettle();
      expect(saved()?.start, addDays(today, 4));
    });

    testWidgets('no break is offered on a schedule that has one', (
      tester,
    ) async {
      await pump(tester, schedule: continuous().copyWith(daysOff: 7));
      expect(find.byKey(RemindersKeys.dose), findsOneWidget);
      expect(find.byKey(RemindersKeys.doseBreak), findsNothing);
    });

    testWidgets('setting up opens the schedule', (tester) async {
      await pump(tester);
      expect(find.byKey(RemindersKeys.doseSetup), findsOneWidget);
      await tester.ensureVisible(find.byKey(RemindersKeys.doseSetup));
      await tester.tap(find.byKey(RemindersKeys.doseSetup));
      await tester.pumpAndSettle();
      expect(find.byType(DoseScheduleScreen), findsOneWidget);
    });
  });

  group('the schedule', () {
    testWidgets('saves the choices made and goes back', (tester) async {
      await pump(
        tester,
        method: Contraception.patchOrRing,
        child: const DoseScheduleScreen(),
      );
      expect(find.byKey(DoseScheduleKeys.preset(1)), findsOneWidget);
      await tester.tap(find.byKey(DoseScheduleKeys.preset(1)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(DoseScheduleKeys.regimen(Regimen.continuous)),
      );
      await tester.tap(
        find.byKey(DoseScheduleKeys.regimen(Regimen.continuous)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.windowLess));
      await tester.tap(find.byKey(DoseScheduleKeys.windowLess));
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.quiet));
      await tester.tap(find.byKey(DoseScheduleKeys.quiet));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.save));
      await tester.tap(find.byKey(DoseScheduleKeys.save));
      await tester.pumpAndSettle();
      expect(saved()?.form, DoseForm.ring);
      expect(saved()?.daysOff, 0);
      expect(saved()?.windowHours, 47);
      expect(saved()?.quietHours, isTrue);
    });

    testWidgets('custom days can be typed', (tester) async {
      await pump(tester, child: const DoseScheduleScreen());
      expect(find.byKey(DoseScheduleKeys.custom), findsOneWidget);
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.custom));
      await tester.tap(find.byKey(DoseScheduleKeys.custom));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(DoseScheduleKeys.daysOn), '24');
      await tester.enterText(find.byKey(DoseScheduleKeys.daysOff), '4');
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.save));
      await tester.tap(find.byKey(DoseScheduleKeys.save));
      await tester.pumpAndSettle();
      expect((saved()?.daysOn, saved()?.daysOff), (24, 4));
    });

    testWidgets('links the source of the window', (tester) async {
      final urls = RecordingUrlOpener();
      await pump(tester, child: const DoseScheduleScreen(), urls: urls);
      expect(find.byKey(DoseScheduleKeys.source), findsOneWidget);
      await tester.ensureVisible(find.byKey(DoseScheduleKeys.source));
      await tester.tap(find.byKey(DoseScheduleKeys.source));
      expect(urls.opened, [
        Uri.parse(dosePresetsFor(Contraception.combinedPill).first.source.url),
      ]);
    });
  });
}
