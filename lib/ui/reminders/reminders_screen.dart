// Reminders: a daily nudge to log, at a time of the user's choosing. Phones
// only; the web cannot schedule a notification for a closed tab.

import 'package:lilith/data/reminder_repository.dart';
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
                if (vm.wasRefused)
                  const ProblemText(
                    key: RemindersKeys.refused,
                    "Notifications are off for Lilith in your phone's "
                    'settings. Allow them there, then try again.',
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          const Text(
            'The reminder is set on this phone only and never leaves it.',
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
