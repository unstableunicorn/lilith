// The three ways to use Lilith, as one choice. Shown when a new person
// starts, and in Settings afterwards.

import 'package:lilith/domain/app_mode.dart';
import 'package:material_ui/material_ui.dart';

/// What each way is called.
String modeTitle(AppMode mode) => switch (mode) {
  AppMode.tracker => 'Track my own cycle',
  AppMode.partner => 'Follow someone who shares with me',
  AppMode.both => 'Both',
};

/// What each way gives.
String modeDescription(AppMode mode) => switch (mode) {
  AppMode.tracker =>
    'Log periods, temperatures and symptoms, and see your predictions.',
  AppMode.partner =>
    'See their next period and calendar. Nothing of your own to log.',
  AppMode.both =>
    'Track your own cycle, with the person you follow at the top of Today.',
};

class ModeChooser extends StatelessWidget {
  const ModeChooser({
    required this.mode,
    required this.onChanged,
    required this.keyFor,
    super.key,
  });

  final AppMode mode;
  final ValueChanged<AppMode> onChanged;
  final Key Function(AppMode) keyFor;

  @override
  Widget build(BuildContext context) => RadioGroup<AppMode>(
    groupValue: mode,
    onChanged: (chosen) {
      if (chosen != null) onChanged(chosen);
    },
    child: Column(
      children: [
        for (final m in AppMode.values)
          RadioListTile<AppMode>(
            key: keyFor(m),
            value: m,
            contentPadding: EdgeInsets.zero,
            title: Text(modeTitle(m)),
            subtitle: Text(modeDescription(m)),
          ),
      ],
    ),
  );
}
