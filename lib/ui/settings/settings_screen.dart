// Settings: the app lock, reminders, what each tab shows on this device,
// and the security key of an encrypted pod.

import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/page_settings.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/data_route.dart';
import 'package:lilith/ui/lock/pin_setup_screen.dart';
import 'package:lilith/ui/mode/mode_chooser.dart';
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
  static const Key tryingToConceive = Key('settings.tryingToConceive');
  static const Key showFertileWindow = Key('settings.showFertileWindow');
  static const Key securityKey = Key('settings.securityKey');
  static const Key appLock = Key('settings.appLock');
  static const Key appLockBiometrics = Key('settings.appLockBiometrics');
  static Key mode(AppMode m) => Key('settings.mode.${m.name}');
  static Key logGroup(LogGroup g) => Key('settings.logGroup.${g.name}');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PageSettingsRepository>();
    final s = repo.settings;
    final canChangeKey = context.watch<SetupRepository>().canChangeKey;
    final lock = context.watch<AppLockRepository?>();
    // Absent when Settings is opened without the data.
    final health = context.watch<HealthRepository?>();
    final mode = health?.data.modeInForce ?? AppMode.tracker;
    Future<void> set(PageSettings next) => repo.update(next);
    return PageScaffold(
      title: 'Settings',
      children: [
        if (lock != null)
          AppCard(
            icon: Icons.lock_outline_rounded,
            title: 'App lock',
            child: Column(
              children: [
                SwitchListTile(
                  key: SettingsKeys.appLock,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lock with a PIN'),
                  subtitle: const Text(
                    'On this phone, when Lilith starts and after five '
                    'minutes away',
                  ),
                  value: lock.lock.isEnabled,
                  onChanged: (_) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PinSetupScreen(),
                    ),
                  ),
                ),
                if (lock.lock.isEnabled && lock.biometricsAvailable)
                  SwitchListTile(
                    key: SettingsKeys.appLockBiometrics,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Unlock with your fingerprint or face'),
                    value: lock.lock.biometrics,
                    onChanged: lock.setBiometrics,
                  ),
              ],
            ),
          ),
        if (health != null && health.isLoaded)
          AppCard(
            icon: Icons.people_outline_rounded,
            title: 'How you use Lilith',
            child: ModeChooser(
              mode: mode,
              keyFor: SettingsKeys.mode,
              onChanged: (chosen) => health.apply((d) => d.withMode(chosen)),
            ),
          ),
        // Nothing below is of use to someone who only follows.
        if (mode.tracksOwnCycle) ...[
          AppCard(
            icon: Icons.alarm_rounded,
            title: 'Reminders',
            child: ListTile(
              key: SettingsKeys.reminders,
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily, period and pill reminders'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushWithData(context, const RemindersScreen()),
            ),
          ),
          if (health != null && health.isLoaded)
            AppCard(
              icon: Icons.edit_note_rounded,
              title: 'Log shows',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flow, pain, symptoms and ovulation tests are always '
                    'there. Turn on what else you want to log; it follows '
                    'you to every device.',
                  ),
                  for (final g in LogGroup.values)
                    SwitchListTile(
                      key: SettingsKeys.logGroup(g),
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.label),
                      value: health.data.shownLogGroups.contains(g),
                      onChanged: (shown) =>
                          health.apply((d) => d.withLogGroup(g, shown: shown)),
                    ),
                ],
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
          AppCard(
            icon: Icons.favorite_border_rounded,
            title: 'Fertile window',
            child: Column(
              children: [
                SwitchListTile(
                  key: SettingsKeys.tryingToConceive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trying to conceive'),
                  subtitle: const Text('Show your likely fertile days.'),
                  value: s.tryingToConceive,
                  onChanged: (v) => set(s.copyWith(tryingToConceive: v)),
                ),
                SwitchListTile(
                  key: SettingsKeys.showFertileWindow,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show fertile window'),
                  subtitle: const Text(
                    'As information only. It is not a contraceptive method.',
                  ),
                  value: s.showFertileWindow,
                  onChanged: (v) => set(s.copyWith(showFertileWindow: v)),
                ),
              ],
            ),
          ),
        ],
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
