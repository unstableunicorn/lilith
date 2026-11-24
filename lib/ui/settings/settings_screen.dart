// Settings: reminders, what each tab shows on this device, and the security
// key of an encrypted pod.

import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:lilith/ui/settings/security_key_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class SettingsKeys {
  static const Key reminders = Key('settings.reminders');
  static const Key showFact = Key('settings.showFact');
  static const Key showForecast = Key('settings.showForecast');
  static const Key showCalendar = Key('settings.showCalendar');
  static const Key showTemperatureChart = Key('settings.showTemperatureChart');
  static const Key securityKey = Key('settings.securityKey');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PageSettingsRepository>();
    final s = repo.settings;
    final canChangeKey = context.watch<SetupRepository>().canChangeKey;
    Future<void> set(PageSettings next) => repo.update(next);
    return PageScaffold(
      title: 'Settings',
      children: [
        AppCard(
          icon: Icons.alarm_rounded,
          title: 'Reminders',
          child: ListTile(
            key: SettingsKeys.reminders,
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily reminder to log'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
            ),
          ),
        ),
        AppCard(
          icon: Icons.today_rounded,
          title: 'Today shows',
          child: Column(
            children: [
              SwitchListTile(
                key: SettingsKeys.showForecast,
                contentPadding: EdgeInsets.zero,
                title: const Text('Your forecast for the week'),
                value: s.showForecast,
                onChanged: (v) => set(s.copyWith(showForecast: v)),
              ),
              SwitchListTile(
                key: SettingsKeys.showFact,
                contentPadding: EdgeInsets.zero,
                title: const Text('Fact of the day'),
                value: s.showFact,
                onChanged: (v) => set(s.copyWith(showFact: v)),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.history_rounded,
          title: 'History shows',
          child: Column(
            children: [
              SwitchListTile(
                key: SettingsKeys.showCalendar,
                contentPadding: EdgeInsets.zero,
                title: const Text('Calendar'),
                value: s.showCalendar,
                onChanged: (v) => set(s.copyWith(showCalendar: v)),
              ),
              SwitchListTile(
                key: SettingsKeys.showTemperatureChart,
                contentPadding: EdgeInsets.zero,
                title: const Text('Temperature trend'),
                value: s.showTemperatureChart,
                onChanged: (v) => set(s.copyWith(showTemperatureChart: v)),
              ),
            ],
          ),
        ),
        if (canChangeKey)
          AppCard(
            icon: Icons.key_rounded,
            title: 'Security key',
            child: ListTile(
              key: SettingsKeys.securityKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Change the security key'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SecurityKeyScreen(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
