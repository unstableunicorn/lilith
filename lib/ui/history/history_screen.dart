// The History tab: the temperature trend, then cycles, days and readings.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/history/history_view_model.dart';
import 'package:lilith/ui/log/log_summary.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class HistoryKeys {
  static const Key loading = Key('history.loading');
  static const Key error = Key('history.error');
  static const Key dismissError = Key('history.dismissError');
  static const Key empty = Key('history.empty');
  static const Key confirm = Key('history.confirm');
  static const Key cancel = Key('history.cancel');
  static Key cycle(DateTime d) => Key('history.cycle.$d');
  static Key removeCycle(DateTime d) => Key('history.removeCycle.$d');
  static Key day(DateTime d) => Key('history.day.$d');
  static Key reading(DateTime d) => Key('history.reading.$d');
  static Key removeReading(DateTime d) => Key('history.removeReading.$d');
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => HistoryViewModel(context.read<HealthRepository>()),
    child: const _HistoryView(),
  );
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistoryViewModel>();
    final today = DateTime.now();
    String date(DateTime d) => formatShortDate(d, today: today);
    return PageScaffold(
      title: 'History',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: HistoryKeys.error,
            message: _describe(error),
            dismissKey: HistoryKeys.dismissError,
            onDismiss: vm.clearError,
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
          if (vm.chartReadings.isNotEmpty)
            AppCard(
              icon: Icons.thermostat_rounded,
              title: 'Temperature trend',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last ${vm.chartReadings.length} readings. Red lines mark '
                    'period starts.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TemperatureChart(
                    readings: vm.chartReadings,
                    periodStarts: vm.periodStarts,
                  ),
                ],
              ),
            ),
          if (vm.cycles.isNotEmpty) const SectionHeading('Cycles'),
          for (final c in vm.cycles)
            ListTile(
              key: HistoryKeys.cycle(c.start),
              leading: const Icon(Icons.water_drop_rounded),
              title: Text('Started ${date(c.start)}'),
              subtitle: Text(
                c.length == null ? 'Current cycle' : '${c.length} days',
              ),
              trailing: IconButton(
                key: HistoryKeys.removeCycle(c.start),
                tooltip: 'Remove this period start',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirm(
                  context,
                  'Remove the period start on ${date(c.start)}?',
                  () => vm.removePeriod(c.start),
                ),
              ),
            ),
          if (vm.days.isNotEmpty) const SectionHeading('Days'),
          for (final log in vm.days)
            ListTile(
              key: HistoryKeys.day(log.date),
              leading: const Icon(Icons.edit_note_rounded),
              title: Text(formatDay(log.date)),
              subtitle: Text(logSummary(log)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.read<ShellTabs>().openLog(log.date),
            ),
          if (vm.readings.isNotEmpty) const SectionHeading('Readings'),
          for (final r in vm.readings)
            ListTile(
              key: HistoryKeys.reading(r.date),
              leading: const Icon(Icons.thermostat_rounded),
              title: Text('${r.celsius} °C'),
              subtitle: Text(formatDay(r.date)),
              trailing: IconButton(
                key: HistoryKeys.removeReading(r.date),
                tooltip: 'Remove this reading',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirm(
                  context,
                  'Remove the reading from ${date(r.date)}?',
                  () => vm.removeReading(r.date),
                ),
              ),
            ),
        ],
      ],
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
