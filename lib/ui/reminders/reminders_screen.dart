// Reminders: a daily nudge to log and reminders around the next period, at a
// time of the user's choosing. Phones only; the web cannot schedule a
// notification for a closed tab.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/data_route.dart';
import 'package:lilith/ui/reminders/dose_schedule_screen.dart';
import 'package:lilith/ui/reminders/reminders_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class RemindersKeys {
  static const Key toggle = Key('reminders.toggle');
  static const Key time = Key('reminders.time');
  static const Key refused = Key('reminders.refused');
  static const Key unavailable = Key('reminders.unavailable');
  static const Key beforePeriod = Key('reminders.beforePeriod');
  static const Key daysBefore = Key('reminders.daysBefore');
  static const Key whenLate = Key('reminders.whenLate');
  static const Key dose = Key('reminders.dose');
  static const Key doseToggle = Key('reminders.doseToggle');
  static const Key doseSetup = Key('reminders.doseSetup');
  static const Key doseBreak = Key('reminders.doseBreak');
  static const Key exact = Key('reminders.exact');
  static const Key test = Key('reminders.test');
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => RemindersViewModel(
      context.read<ReminderRepository>(),
      health: context.read<HealthRepository?>(),
    ),
    child: const _RemindersView(),
  );
}

class _RemindersView extends StatelessWidget {
  const _RemindersView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RemindersViewModel>();
    return PageScaffold(
      title: 'Reminders',
      children: [
        if (!vm.isAvailable)
          const AppCard(
            key: RemindersKeys.unavailable,
            icon: Icons.notifications_off_outlined,
            title: 'Not on the web',
            tone: CardTone.callout,
            child: Text(
              'A web page cannot remind you once it is closed. Reminders '
              'work in the Android app.',
            ),
          )
        else ...[
          AppCard(
            icon: Icons.alarm_rounded,
            title: 'Daily reminder to log',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: RemindersKeys.toggle,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remind me every day'),
                  subtitle: Text(vm.isEnabled ? 'At ${vm.timeText}' : 'Off'),
                  value: vm.isEnabled,
                  onChanged: vm.setEnabled,
                ),
                TextButton.icon(
                  key: RemindersKeys.time,
                  onPressed: () => _pickTime(context, vm),
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('Change the time (${vm.timeText})'),
                ),
                TextButton.icon(
                  key: RemindersKeys.test,
                  onPressed: vm.sendTest,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Send a test notification now'),
                ),
              ],
            ),
          ),
          if (vm.offersPeriod) ...[
            const SizedBox(height: Space.md),
            _PeriodCard(vm: vm),
          ],
          if (vm.offersDose) ...[
            const SizedBox(height: Space.md),
            _DoseCard(vm: vm),
          ],
          if (vm.offersExact) ...[
            const SizedBox(height: Space.md),
            AppCard(
              icon: Icons.timer_outlined,
              title: 'On time',
              tone: CardTone.callout,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your phone may show reminders an hour or more late. '
                    'Allow exact times to have them on the minute.',
                  ),
                  TextButton.icon(
                    key: RemindersKeys.exact,
                    onPressed: vm.requestExact,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Allow exact times'),
                  ),
                ],
              ),
            ),
          ],
          if (vm.wasRefused)
            const ProblemText(
              key: RemindersKeys.refused,
              "Notifications are off for Lilith in your phone's "
              'settings. Allow them there, then try again.',
            ),
          const SizedBox(height: Space.md),
          Text(
            vm.offersDose
                ? 'Reminders are set on this phone only. They show at the '
                      'time above, apart from your schedule, which keeps its '
                      'own time. The schedule and what you mark done are '
                      'kept on your pod.'
                : 'Reminders are set on this phone only and never leave it. '
                      'They all show at the time above.',
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, RemindersViewModel vm) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: vm.hour, minute: vm.minute),
      helpText: 'When to remind you',
    );
    if (picked == null) return;
    await vm.setTime(hour: picked.hour, minute: picked.minute);
  }
}

/// The pill, patch or ring reminders: the switch, the schedule they follow,
/// a break on a schedule without one, and the offer of exact times.
class _DoseCard extends StatelessWidget {
  const _DoseCard({required this.vm});

  final RemindersViewModel vm;

  @override
  Widget build(BuildContext context) {
    final schedule = vm.doseSchedule;
    return AppCard(
      key: RemindersKeys.dose,
      icon: Icons.medication_outlined,
      title: vm.doseTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: RemindersKeys.doseToggle,
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me'),
            subtitle: Text(
              !vm.doseOn
                  ? 'Off'
                  : schedule == null
                  ? 'Set up your schedule below'
                  : 'At ${_time(schedule)}, then through its window',
            ),
            value: vm.doseOn,
            onChanged: vm.setDoseOn,
          ),
          TextButton.icon(
            key: RemindersKeys.doseSetup,
            onPressed: () => pushWithData(context, const DoseScheduleScreen()),
            icon: const Icon(Icons.event_repeat_rounded),
            label: Text(
              schedule == null ? 'Set up your schedule' : 'Change the schedule',
            ),
          ),
          if (vm.offersBreak)
            TextButton.icon(
              key: RemindersKeys.doseBreak,
              onPressed: vm.startBreak,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Start a 4-day break today'),
            ),
        ],
      ),
    );
  }

  static String _time(ContraceptionSchedule s) =>
      '${s.hour.toString().padLeft(2, '0')}:'
      '${s.minute.toString().padLeft(2, '0')}';
}

/// The reminders before the period's usual window and once it is late.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.vm});

  final RemindersViewModel vm;

  @override
  Widget build(BuildContext context) => AppCard(
    icon: Icons.water_drop_outlined,
    title: 'Your period',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: RemindersKeys.beforePeriod,
          contentPadding: EdgeInsets.zero,
          title: const Text('Before my period'),
          subtitle: Text(
            vm.beforePeriod
                ? '${vm.daysBeforeText} your usual window, as it starts, '
                      'and on the expected day'
                : 'Off',
          ),
          value: vm.beforePeriod,
          onChanged: vm.setBeforePeriod,
        ),
        if (vm.beforePeriod)
          Slider(
            key: RemindersKeys.daysBefore,
            value: vm.daysBefore.toDouble(),
            min: ReminderSetting.minDaysBefore.toDouble(),
            max: ReminderSetting.maxDaysBefore.toDouble(),
            divisions:
                ReminderSetting.maxDaysBefore - ReminderSetting.minDaysBefore,
            label: vm.daysBeforeText,
            semanticFormatterCallback: (_) => vm.daysBeforeText,
            onChanged: (v) => vm.setDaysBefore(v.round()),
          ),
        SwitchListTile(
          key: RemindersKeys.whenLate,
          contentPadding: EdgeInsets.zero,
          title: const Text('When it is late'),
          subtitle: Text(
            vm.whenLate
                ? 'As your usual window ends, the day after, then a daily '
                      'check-in you can snooze'
                : 'Off',
          ),
          value: vm.whenLate,
          onChanged: vm.setWhenLate,
        ),
      ],
    ),
  );
}
