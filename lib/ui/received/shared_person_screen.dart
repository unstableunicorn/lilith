// One sharer's cycle data, read-only: their prediction, numbers, trend and
// lists, fetched from their pod when the page opens or is refreshed.

import 'dart:async';

import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
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
  static Key daySummary(DateTime d) => Key('sharedPerson.daySummary.$d');
  static Key dayDose(DateTime d) => Key('sharedPerson.dayDose.$d');
  static const Key calendar = Key('sharedPerson.calendar');
  static const Key calendarPrev = Key('sharedPerson.calendarPrev');
  static const Key calendarNext = Key('sharedPerson.calendarNext');
  static Key calendarDay(DateTime d) => Key('sharedPerson.calendarDay.$d');
  static const Key updated = Key('sharedPerson.updated');
  static const Key disclaimer = Key('sharedPerson.disclaimer');
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
  Widget build(BuildContext context) => SharedPersonScope(
    share: share,
    now: now,
    child: const _SharedPersonView(),
  );
}

/// Gives [child] the view model of one sharer, fetching their copy the
/// first time it is looked at.
class SharedPersonScope extends StatelessWidget {
  const SharedPersonScope({
    required this.share,
    required this.child,
    this.now = DateTime.now,
    super.key,
  });

  final ReceivedShare share;
  final DateTime Function() now;
  final Widget child;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) {
      final repo = context.read<ReceivedShareRepository>();
      final vm = SharedPersonViewModel(repo, share, now: now);
      if (repo.viewOf(share) is SharedViewLoading) {
        unawaited(Future<void>.microtask(vm.refresh));
      }
      return vm;
    },
    child: child,
  );
}

class _SharedPersonView extends StatelessWidget {
  const _SharedPersonView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SharedPersonViewModel>();
    return PageScaffold(
      title: vm.share.label,
      onRefresh: vm.refresh,
      actions: [
        IconButton(
          key: SharedPersonKeys.refresh,
          tooltip: 'Fetch again',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: vm.isLoading ? null : vm.refresh,
        ),
      ],
      children: const [SharedPersonBody()],
    );
  }
}

/// What one sharer shares, below whatever heads the page. Needs a
/// [SharedPersonScope] above it.
class SharedPersonBody extends StatelessWidget {
  const SharedPersonBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SharedPersonViewModel>();
    final theme = Theme.of(context);
    String date(DateTime d) => formatShortDate(d, today: vm.today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          SharedViewReady() ||
          SharedViewPhases() when !vm.hasData => const AppCard(
            key: SharedPersonKeys.empty,
            icon: Icons.insights_rounded,
            title: 'Nothing logged yet',
            child: Text('They have not logged anything to show.'),
          ),
          SharedViewReady() => _Data(vm: vm, date: date),
          SharedViewPhases() => _Phases(vm: vm, date: date),
        },
      ],
    );
  }
}

/// A "phases only" share: the next period and a read-only calendar.
class _Phases extends StatelessWidget {
  const _Phases({required this.vm, required this.date});

  final SharedPersonViewModel vm;
  final String Function(DateTime) date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
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
                style: theme.textTheme.titleLarge,
              ),
              if (vm.phasesCycleLine case final line?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(line),
                ),
              if (vm.phasesUpdatedText case final updated?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    key: SharedPersonKeys.updated,
                    updated,
                    style: small,
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          key: SharedPersonKeys.calendar,
          icon: Icons.calendar_month_rounded,
          title: 'Calendar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MonthCalendar(
                title: formatMonth(vm.month),
                days: vm.phasesDays,
                leadingBlanks: vm.calendarLeadingBlanks,
                today: vm.today,
                onPrevious: vm.previousMonth,
                onNext: vm.nextMonth,
                dayKey: SharedPersonKeys.calendarDay,
                previousKey: SharedPersonKeys.calendarPrev,
                nextKey: SharedPersonKeys.calendarNext,
              ),
              if (vm.phasesDisclaimer case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    key: SharedPersonKeys.disclaimer,
                    text,
                    style: small,
                  ),
                ),
            ],
          ),
        ),
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
              periods: vm.periodSpans,
              luteal: vm.lutealSpan,
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vm.summaryLine(log) case final summary?)
                  Text(key: SharedPersonKeys.daySummary(log.date), summary),
                if (vm.doseText(log.date) case final dose?)
                  Text(key: SharedPersonKeys.dayDose(log.date), dose),
              ],
            ),
          ),
      ],
    );
  }
}
