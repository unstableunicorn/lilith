// One sharer's cycle data, read-only: their prediction, numbers, trend and
// lists, fetched from their pod when the page opens or is refreshed.

import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/log/log_summary.dart';
import 'package:lilith/ui/received/received_view_model.dart';
import 'package:lilith/ui/received/shared_person_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class SharedPersonKeys {
  static const Key loading = Key('sharedPerson.loading');
  static const Key failed = Key('sharedPerson.failed');
  static const Key empty = Key('sharedPerson.empty');
  static const Key prediction = Key('sharedPerson.prediction');
  static const Key stats = Key('sharedPerson.stats');
  static const Key refresh = Key('sharedPerson.refresh');
  static Key cycle(DateTime d) => Key('sharedPerson.cycle.$d');
  static Key day(DateTime d) => Key('sharedPerson.day.$d');
}

class SharedPersonScreen extends StatelessWidget {
  const SharedPersonScreen({
    required this.share,
    this.now = DateTime.now,
    super.key,
  });

  final ReceivedShare share;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) {
      final repo = context.read<ReceivedShareRepository>();
      final vm = SharedPersonViewModel(repo, share, now: now);
      if (repo.viewOf(share) is SharedViewLoading) vm.refresh();
      return vm;
    },
    child: const _SharedPersonView(),
  );
}

class _SharedPersonView extends StatelessWidget {
  const _SharedPersonView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SharedPersonViewModel>();
    final theme = Theme.of(context);
    String date(DateTime d) => formatShortDate(d, today: vm.today);
    return PageScaffold(
      title: vm.share.label,
      actions: [
        IconButton(
          key: SharedPersonKeys.refresh,
          tooltip: 'Fetch again',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      children: [
        Text(
          'Read-only, from their pod. Shared with you by ${vm.share.label}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.md),
        switch (vm.view) {
          SharedViewLoading() => const BusyIndicator(
            key: SharedPersonKeys.loading,
            label: 'Fetching from their pod',
          ),
          SharedViewFailed(:final error, :final detail) => AppCard(
            key: SharedPersonKeys.failed,
            icon: Icons.info_outline_rounded,
            title: error == ReceivedShareError.ended
                ? 'This share has ended'
                : 'Could not fetch',
            tone: CardTone.callout,
            child: Text(
              error == ReceivedShareError.ended
                  ? 'They have stopped sharing with you, or the share has '
                        'run out. You can remove it from the list.'
                  : '${describeReceivedError(error)}'
                        '${detail == null ? '' : ' ($detail)'}',
            ),
          ),
          SharedViewReady() when !vm.hasData => const AppCard(
            key: SharedPersonKeys.empty,
            icon: Icons.insights_rounded,
            title: 'Nothing logged yet',
            child: Text('They have not logged anything to show.'),
          ),
          SharedViewReady() => _Data(vm: vm, date: date),
        },
      ],
    );
  }
}

class _Data extends StatelessWidget {
  const _Data({required this.vm, required this.date});

  final SharedPersonViewModel vm;
  final String Function(DateTime) date;

  @override
  Widget build(BuildContext context) {
    final p = vm.prediction!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          key: SharedPersonKeys.prediction,
          icon: Icons.favorite_rounded,
          title: 'Next period',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.nextPeriodText ?? 'Not enough logged yet to predict.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (p.lastPeriodStart case final start?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    'Cycle day ${p.currentCycleDay}, since ${date(start)}',
                  ),
                ),
            ],
          ),
        ),
        Row(
          key: SharedPersonKeys.stats,
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.calendar_today_rounded,
                label: 'Cycle day',
                value: p.currentCycleDay?.toString() ?? '—',
              ),
            ),
            Expanded(
              child: StatTile(
                icon: Icons.thermostat_rounded,
                label: 'Latest temp',
                value: switch (vm.latestReading) {
                  final r? => '${r.celsius} °C',
                  null => '—',
                },
              ),
            ),
            Expanded(
              child: StatTile(
                icon: Icons.loop_rounded,
                label: 'Avg cycle',
                value: switch (p.averageCycleLength) {
                  final d? => '${d.toStringAsFixed(1)} days',
                  null => '—',
                },
              ),
            ),
          ],
        ),
        if (vm.chartReadings.isNotEmpty)
          AppCard(
            icon: Icons.thermostat_rounded,
            title: 'Temperature trend',
            child: TemperatureChart(
              readings: vm.chartReadings,
              periodStarts: vm.periodStarts,
            ),
          ),
        if (vm.cycles.isNotEmpty) const SectionHeading('Cycles'),
        for (final c in vm.cycles)
          ListTile(
            key: SharedPersonKeys.cycle(c.start),
            leading: const Icon(Icons.water_drop_rounded),
            title: Text('Started ${date(c.start)}'),
            subtitle: Text(
              c.length == null ? 'Current cycle' : '${c.length} days',
            ),
          ),
        if (vm.days.isNotEmpty) const SectionHeading('Days'),
        for (final log in vm.days)
          ListTile(
            key: SharedPersonKeys.day(log.date),
            leading: const Icon(Icons.edit_note_rounded),
            title: Text(formatDay(log.date)),
            subtitle: Text(logSummary(log)),
          ),
      ],
    );
  }
}
