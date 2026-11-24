// The History tab: the temperature trend, then cycles, days and readings.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/history/history_view_model.dart';
import 'package:lilith/ui/log/log_summary.dart';
import 'package:lilith/ui/period/period_form_screen.dart';
import 'package:lilith/ui/period/period_form_view_model.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class HistoryKeys {
  static const Key loading = Key('history.loading');
  static const Key error = Key('history.error');
  static const Key dismissError = Key('history.dismissError');
  static const Key empty = Key('history.empty');
  static const Key nightChart = Key('history.nightChart');
  static const Key calendar = Key('history.calendar');
  static const Key calendarPrev = Key('history.calendarPrev');
  static const Key calendarNext = Key('history.calendarNext');
  static Key calendarDay(DateTime d) => Key('history.calendarDay.$d');
  static const Key confirm = Key('history.confirm');
  static const Key cancel = Key('history.cancel');
  static Key cycle(DateTime d) => Key('history.cycle.$d');
  static Key removeCycle(DateTime d) => Key('history.removeCycle.$d');
  static Key editCycle(DateTime d) => Key('history.editCycle.$d');
  static const Key addPeriod = Key('history.addPeriod');
  static const Key addReading = Key('history.addReading');
  static const Key addReadingDay = Key('history.addReadingDay');
  static const Key addReadingValue = Key('history.addReadingValue');
  static const Key addReadingSave = Key('history.addReadingSave');
  static const Key addReadingProblem = Key('history.addReadingProblem');
  static Key day(DateTime d) => Key('history.day.$d');
  static Key reading(DateTime d) => Key('history.reading.$d');
  static Key removeReading(DateTime d) => Key('history.removeReading.$d');
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        HistoryViewModel(context.read<HealthRepository>(), now: now),
    child: const _HistoryView(),
  );
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final shows = context.watch<PageSettingsRepository>().settings;
    final today = vm.today;
    String date(DateTime d) => formatShortDate(d, today: today);
    return PageScaffold(
      title: 'History',
      actions: const [AppMenu()],
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: HistoryKeys.error,
            message: _describe(error),
            dismissKey: HistoryKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        Wrap(
          spacing: Space.sm,
          children: [
            TextButton.icon(
              key: HistoryKeys.addPeriod,
              onPressed: () => _openForm(context, PeriodFormMode.pastPeriod),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a past period'),
            ),
            TextButton.icon(
              key: HistoryKeys.addReading,
              onPressed: () => _addReading(context, vm),
              icon: const Icon(Icons.thermostat_rounded),
              label: const Text('Add a reading'),
            ),
          ],
        ),
        if (!vm.isLoaded)
          const BusyIndicator(
            key: HistoryKeys.loading,
            label: 'Loading your data',
          )
        else if (!vm.hasHistory)
          const AppCard(
            key: HistoryKeys.empty,
            icon: Icons.insights_rounded,
            title: 'Nothing here yet',
            child: Text(
              'Your periods, days and temperatures will be listed here as '
              'you log them.',
            ),
          )
        else ...[
          if (shows.showCalendar)
            AppCard(
              key: HistoryKeys.calendar,
              icon: Icons.calendar_month_rounded,
              title: 'Calendar',
              child: MonthCalendar(
                title: formatMonth(vm.month),
                days: vm.calendarDays,
                leadingBlanks: vm.calendarLeadingBlanks,
                today: today,
                onPrevious: vm.previousMonth,
                onNext: vm.nextMonth,
                onDay: (day) => context.read<ShellTabs>().openLog(day),
                dayKey: HistoryKeys.calendarDay,
                previousKey: HistoryKeys.calendarPrev,
                nextKey: HistoryKeys.calendarNext,
              ),
            ),
          if (shows.showTemperatureChart && vm.chartReadings.isNotEmpty)
            AppCard(
              icon: Icons.thermostat_rounded,
              title: 'Temperature trend',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your last ${vm.chartReadings.length} readings, with '
                    'your periods and the days after ovulation shaded.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TemperatureChart(
                    readings: vm.chartReadings,
                    periodStarts: vm.periodStarts,
                    periods: vm.periodSpans,
                    luteal: vm.lutealSpan,
                  ),
                ],
              ),
            ),
          if (vm.chartNights.isNotEmpty)
            AppCard(
              key: HistoryKeys.nightChart,
              icon: Icons.watch_rounded,
              title: 'Change from your baseline',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your last ${vm.chartNights.length} nights from your '
                    'wearable, above or below your average over them.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TrendChart(
                    points: [
                      for (final n in vm.nightsFromAverage)
                        ChartPoint(date: n.date, value: n.celsius),
                    ],
                    unit: '°C',
                    menstrual: vm.periodSpans,
                    luteal: vm.lutealSpan,
                    starts: vm.periodStarts,
                    zeroLine: true,
                    subject: 'change from baseline',
                  ),
                ],
              ),
            ),
          if (vm.cycles.isNotEmpty) const SectionHeading('Cycles'),
          for (final c in vm.cycles)
            _CycleTile(
              cycle: c,
              date: date,
              onEdit: () => _openForm(
                context,
                PeriodFormMode.edit,
                editing: vm.periodStarting(c.start),
              ),
              onRemove: () => _confirm(
                context,
                'Remove the period start on ${date(c.start)}?',
                () => vm.removePeriod(c.start),
              ),
              onRemoveReading: (r) => _confirm(
                context,
                'Remove the reading from ${date(r.date)}?',
                () => vm.removeReading(r.date),
              ),
            ),
          if (vm.daysBeforeFirstPeriod.isNotEmpty ||
              vm.readingsBeforeFirstPeriod.isNotEmpty) ...[
            SectionHeading(
              vm.cycles.isEmpty ? 'Logged so far' : 'Before your first period',
            ),
            for (final log in vm.daysBeforeFirstPeriod) _DayTile(log: log),
            for (final r in vm.readingsBeforeFirstPeriod)
              _ReadingTile(
                reading: r,
                onRemove: () => _confirm(
                  context,
                  'Remove the reading from ${date(r.date)}?',
                  () => vm.removeReading(r.date),
                ),
              ),
          ],
        ],
      ],
    );
  }

  void _openForm(
    BuildContext context,
    PeriodFormMode mode, {
    PeriodEvent? editing,
  }) {
    final repo = context.read<HealthRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: repo,
          child: PeriodFormScreen(mode: mode, editing: editing),
        ),
      ),
    );
  }

  Future<void> _addReading(BuildContext context, HistoryViewModel vm) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AddReadingDialog(vm: vm),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    String question,
    Future<void> Function() onConfirm,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            key: HistoryKeys.cancel,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: HistoryKeys.confirm,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes ?? false) await onConfirm();
  }

  String _describe(RepositoryError error) => switch (error) {
    RepositoryError.saveFailed =>
      'Your change is kept here but could not be saved to your pod.',
    RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
    _ => 'Your data could not be read from your pod.',
  };
}

/// A day and a temperature, checked before they are kept.
class _AddReadingDialog extends StatefulWidget {
  const _AddReadingDialog({required this.vm});

  final HistoryViewModel vm;

  @override
  State<_AddReadingDialog> createState() => _AddReadingDialogState();
}

class _AddReadingDialogState extends State<_AddReadingDialog> {
  late DateTime _day = widget.vm.today;
  final _value = TextEditingController();
  bool _refused = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a reading'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: HistoryKeys.addReadingDay,
          onPressed: _pickDay,
          icon: const Icon(Icons.event_rounded),
          label: Text(formatDay(_day)),
        ),
        TextField(
          key: HistoryKeys.addReadingValue,
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Temperature (°C)',
            hintText: '36.4',
          ),
          onSubmitted: (_) => _save(),
        ),
        if (_refused)
          const ProblemText(
            key: HistoryKeys.addReadingProblem,
            'Enter a body temperature between '
            '${TemperatureReading.minCelsius} and '
            '${TemperatureReading.maxCelsius} °C.',
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: HistoryKeys.addReadingSave,
        onPressed: _save,
        child: const Text('Save'),
      ),
    ],
  );

  Future<void> _pickDay() async {
    final today = widget.vm.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year - 3, today.month, today.day),
      lastDate: today,
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final celsius = double.tryParse(_value.text.replaceAll(',', '.'));
    final saved = celsius != null && await widget.vm.addReading(_day, celsius);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _refused = true);
    }
  }
}

/// One cycle, open by default: its period, then the days and readings in it.
class _CycleTile extends StatelessWidget {
  const _CycleTile({
    required this.cycle,
    required this.date,
    required this.onEdit,
    required this.onRemove,
    required this.onRemoveReading,
  });

  final CycleEntry cycle;
  final String Function(DateTime) date;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final void Function(TemperatureReading) onRemoveReading;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: HistoryKeys.cycle(cycle.start),
    initiallyExpanded: true,
    leading: const Icon(Icons.water_drop_rounded),
    title: Text('Started ${date(cycle.start)}'),
    subtitle: Text(HistoryViewModel.cycleText(cycle)),
    children: [
      Wrap(
        spacing: Space.sm,
        children: [
          TextButton.icon(
            key: HistoryKeys.editCycle(cycle.start),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit period'),
          ),
          TextButton.icon(
            key: HistoryKeys.removeCycle(cycle.start),
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove period'),
          ),
        ],
      ),
      for (final log in cycle.days) _DayTile(log: log),
      for (final r in cycle.readings)
        _ReadingTile(reading: r, onRemove: () => onRemoveReading(r)),
      if (cycle.days.isEmpty && cycle.readings.isEmpty)
        const ListTile(
          dense: true,
          title: Text('Nothing else logged in this cycle.'),
        ),
    ],
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.log});

  final DailyLog log;

  @override
  Widget build(BuildContext context) => ListTile(
    key: HistoryKeys.day(log.date),
    leading: const Icon(Icons.edit_note_rounded),
    title: Text(formatDay(log.date)),
    subtitle: Text(logSummary(log)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.read<ShellTabs>().openLog(log.date),
  );
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading, required this.onRemove});

  final TemperatureReading reading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    key: HistoryKeys.reading(reading.date),
    leading: const Icon(Icons.thermostat_rounded),
    title: Text('${reading.celsius} °C'),
    subtitle: Text(formatDay(reading.date)),
    trailing: IconButton(
      key: HistoryKeys.removeReading(reading.date),
      tooltip: 'Remove this reading',
      icon: const Icon(Icons.delete_outline_rounded),
      onPressed: onRemove,
    ),
  );
}
