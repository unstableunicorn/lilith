// Reminders: a daily nudge to log and reminders around the next period, at a
// time of the user's choosing. Phones only; the web cannot schedule a
// notification for a closed tab.

import 'package:lilith/data/reminder_repository.dart';
import 'package:lilith/domain/reminder_setting.dart';
import 'package:lilith/ui/components/components.dart';
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
}

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => RemindersViewModel(context.read<ReminderRepository>()),
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
              ],
            ),
          ),
          if (vm.offersPeriod) ...[
            const SizedBox(height: Space.md),
            _PeriodCard(vm: vm),
          ],
          if (vm.wasRefused)
            const ProblemText(
              key: RemindersKeys.refused,
              "Notifications are off for Lilith in your phone's "
              'settings. Allow them there, then try again.',
            ),
          const SizedBox(height: Space.md),
          const Text(
            'Reminders are set on this phone only and never leave it. They '
            'all show at the time above.',
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
