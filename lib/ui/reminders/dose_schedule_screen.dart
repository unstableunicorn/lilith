// Setting up the pill, patch or ring schedule its reminders follow.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/contraception_schedule.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/reminders/dose_schedule_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class DoseScheduleKeys {
  static Key preset(int i) => Key('doseSchedule.preset.$i');
  static Key regimen(Regimen r) => Key('doseSchedule.regimen.${r.name}');
  static const Key custom = Key('doseSchedule.custom');
  static const Key daysOn = Key('doseSchedule.daysOn');
  static const Key daysOff = Key('doseSchedule.daysOff');
  static const Key start = Key('doseSchedule.start');
  static const Key time = Key('doseSchedule.time');
  static const Key windowLess = Key('doseSchedule.windowLess');
  static const Key windowMore = Key('doseSchedule.windowMore');
  static const Key quiet = Key('doseSchedule.quiet');
  static const Key source = Key('doseSchedule.source');
  static const Key save = Key('doseSchedule.save');
  static const Key error = Key('doseSchedule.error');
}

// The radio value standing for custom days.
const Object _custom = 'custom';

class DoseScheduleScreen extends StatelessWidget {
  const DoseScheduleScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        DoseScheduleViewModel(context.read<HealthRepository>(), now: now),
    child: const _DoseScheduleView(),
  );
}

class _DoseScheduleView extends StatefulWidget {
  const _DoseScheduleView();

  @override
  State<_DoseScheduleView> createState() => _DoseScheduleViewState();
}

class _DoseScheduleViewState extends State<_DoseScheduleView> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DoseScheduleViewModel>();
    final preset = vm.preset;
    final theme = Theme.of(context);
    if (preset == null) {
      return const PageScaffold(
        title: 'Your schedule',
        children: [Text('Choose a pill, patch or ring in your profile first.')],
      );
    }
    final today = vm.now();
    return PageScaffold(
      title: 'Your schedule',
      children: [
        if (vm.presets.length > 1) ...[
          const SectionHeading('Which one'),
          RadioGroup<int>(
            groupValue: vm.presetIndex,
            onChanged: (i) => vm.choosePreset(i!),
            child: Column(
              children: [
                for (final (i, p) in vm.presets.indexed)
                  RadioListTile<int>(
                    key: DoseScheduleKeys.preset(i),
                    title: Text(p.label),
                    value: i,
                  ),
              ],
            ),
          ),
        ],
        if (preset.regimens.length > 1) ...[
          const SectionHeading('How you use it'),
          RadioGroup<Object>(
            groupValue: vm.regimen ?? _custom,
            onChanged: (v) =>
                vm.chooseRegimen(v == _custom ? null : v as Regimen?),
            child: Column(
              children: [
                for (final r in preset.regimens)
                  RadioListTile<Object>(
                    key: DoseScheduleKeys.regimen(r),
                    title: Text(_regimenLabel(r)),
                    value: r,
                  ),
                const RadioListTile<Object>(
                  key: DoseScheduleKeys.custom,
                  title: Text('My own days'),
                  value: _custom,
                ),
              ],
            ),
          ),
          if (vm.regimen == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: DoseScheduleKeys.daysOn,
                      initialValue: '${vm.daysOn}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Days on'),
                      onChanged: (t) => vm.setDaysOn(int.tryParse(t) ?? 1),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: TextFormField(
                      key: DoseScheduleKeys.daysOff,
                      initialValue: '${vm.daysOff}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Days off (0 for none)',
                      ),
                      onChanged: (t) => vm.setDaysOff(int.tryParse(t) ?? 0),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SectionHeading('When'),
        ListTile(
          key: DoseScheduleKeys.start,
          title: const Text('Day 1 of this pack, patch or ring'),
          subtitle: Text(formatDay(vm.start)),
          trailing: const Icon(Icons.edit_calendar_rounded),
          onTap: () => _pickStart(context, vm, today),
        ),
        ListTile(
          key: DoseScheduleKeys.time,
          title: const Text('Time'),
          subtitle: Text(_timeText(vm.hour, vm.minute)),
          trailing: const Icon(Icons.schedule_rounded),
          onTap: () => _pickTime(context, vm),
        ),
        const SectionHeading('How late is still on time'),
        Row(
          children: [
            IconButton(
              key: DoseScheduleKeys.windowLess,
              tooltip: 'An hour less',
              onPressed: () => vm.setWindowHours(vm.windowHours - 1),
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Text(
                vm.windowHours == 1
                    ? 'Up to 1 hour late'
                    : 'Up to ${vm.windowHours} hours late',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: DoseScheduleKeys.windowMore,
              tooltip: 'An hour more',
              onPressed: () => vm.setWindowHours(vm.windowHours + 1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        Text(
          'Reminders follow up through this window, then say once if it has '
          'passed. Your leaflet may differ; it comes first.',
          style: theme.textTheme.bodySmall,
        ),
        TextButton(
          key: DoseScheduleKeys.source,
          onPressed: () =>
              context.read<UrlOpener>()(Uri.parse(preset.source.url)),
          child: Text('Source: ${preset.source.name}'),
        ),
        SwitchListTile(
          key: DoseScheduleKeys.quiet,
          contentPadding: EdgeInsets.zero,
          title: const Text('Quiet overnight'),
          subtitle: const Text(
            'No follow-ups from ${ContraceptionSchedule.quietFrom}:00 to '
            '0${ContraceptionSchedule.quietUntil}:00',
          ),
          value: vm.quietHours,
          onChanged: vm.setQuietHours,
        ),
        const SizedBox(height: Space.md),
        if (_failed)
          const ProblemText(
            key: DoseScheduleKeys.error,
            'Could not save to your pod. Check your connection and try again.',
          ),
        FilledButton(
          key: DoseScheduleKeys.save,
          onPressed: vm.isSaving ? null : () => _save(context, vm),
          child: Text(vm.isSaving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  static String _regimenLabel(Regimen r) => switch (r) {
    Regimen.standard => '21 days on, 7 days off',
    Regimen.shortenedBreak => '21 days on, 4 days off',
    Regimen.tricycling => '9 weeks on, 7 days off',
    Regimen.continuous => 'No break',
  };

  static String _timeText(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart(
    BuildContext context,
    DoseScheduleViewModel vm,
    DateTime today,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.start,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: 'Day 1',
    );
    if (picked != null) vm.setStart(picked);
  }

  Future<void> _pickTime(BuildContext context, DoseScheduleViewModel vm) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: vm.hour, minute: vm.minute),
      helpText: 'When to remind you',
    );
    if (picked != null) vm.setTime(hour: picked.hour, minute: picked.minute);
  }

  Future<void> _save(BuildContext context, DoseScheduleViewModel vm) async {
    final saved = await vm.save();
    if (!context.mounted) return;
    setState(() => _failed = !saved);
    if (!saved) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }
}
