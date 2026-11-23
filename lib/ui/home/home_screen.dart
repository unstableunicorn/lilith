// The Today tab: the prediction, the key numbers and the two quick logs.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/home/home_view_model.dart';
import 'package:lilith/ui/learn/learn_screen.dart';
import 'package:lilith/ui/log/log_summary.dart';
import 'package:lilith/ui/period/period_form_screen.dart';
import 'package:lilith/ui/period/period_form_view_model.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class HomeKeys {
  static const Key loading = Key('home.loading');
  static const Key error = Key('home.error');
  static const Key dismissError = Key('home.dismissError');
  static const Key noData = Key('home.noData');
  static const Key startedToday = Key('home.startedToday');
  static const Key midPeriod = Key('home.midPeriod');
  static const Key notBleeding = Key('home.notBleeding');
  static const Key prediction = Key('home.prediction');
  static const Key stats = Key('home.stats');
  static const Key avgPeriod = Key('home.avgPeriod');
  static const Key forecast = Key('home.forecast');
  static const Key fact = Key('home.fact');
  static const Key factSource = Key('home.factSource');
  static const Key learn = Key('home.learn');
  static const Key daysUntil = Key('home.daysUntil');
  static const Key lastPeriod = Key('home.lastPeriod');
  static const Key logPeriod = Key('home.logPeriod');
  static const Key temperature = Key('home.temperature');
  static const Key logTemperature = Key('home.logTemperature');
  static const Key temperatureProblem = Key('home.temperatureProblem');
  static const Key todaysReading = Key('home.todaysReading');
  static const Key logDay = Key('home.logDay');
  static const Key todaysLog = Key('home.todaysLog');
  static const Key invite = Key('home.invite');
  static const Key acceptInvite = Key('home.acceptInvite');
  static const Key dismissInvite = Key('home.dismissInvite');
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        HomeViewModel(context.read<HealthRepository>(), now: now),
    child: const _HomeView(),
  );
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _temperature = TextEditingController();
  bool _temperatureRefused = false;

  @override
  void dispose() {
    _temperature.dispose();
    super.dispose();
  }

  Future<void> _logTemperature(HomeViewModel vm) async {
    final value = double.tryParse(
      _temperature.text.trim().replaceAll(',', '.'),
    );
    final accepted = value != null && await vm.logTemperature(value);
    if (!mounted) return;
    setState(() => _temperatureRefused = !accepted);
    if (accepted) _temperature.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return PageScaffold(
      title: 'Lilith',
      actions: [
        IconButton(
          key: HomeKeys.learn,
          tooltip: 'Learn',
          icon: const Icon(Icons.menu_book_rounded),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const LearnScreen())),
        ),
        const AppMenu(),
      ],
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: HomeKeys.error,
            message: _describe(error),
            dismissKey: HomeKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        if (context.watch<ReceivedShareRepository>().pendingInvite
            case final invite?)
          _InviteCard(invite: invite, now: vm.now),
        if (!vm.isLoaded)
          const BusyIndicator(key: HomeKeys.loading, label: 'Loading your data')
        else ...[
          if (!vm.hasData)
            _WelcomeCard(vm: vm)
          else ...[
            _PredictionCard(vm: vm),
            _StatsRow(vm: vm),
            if (vm.forecast.hasData) _ForecastCard(vm: vm),
          ],
          AppCard(
            icon: Icons.water_drop_rounded,
            title: 'Quick log',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: HomeKeys.logPeriod,
                  onPressed: vm.logPeriodStart,
                  icon: const Icon(Icons.water_drop),
                  label: const Text('My period started today'),
                ),
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: HomeKeys.temperature,
                        controller: _temperature,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: "Today's temperature (°C)",
                          hintText: '36.4',
                        ),
                        onSubmitted: (_) => _logTemperature(vm),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    FilledButton.tonal(
                      key: HomeKeys.logTemperature,
                      onPressed: () => _logTemperature(vm),
                      child: const Text('Log'),
                    ),
                  ],
                ),
                if (_temperatureRefused)
                  const ProblemText(
                    key: HomeKeys.temperatureProblem,
                    'Enter a body temperature between '
                    '${HomeViewModel.minCelsius} and '
                    '${HomeViewModel.maxCelsius} °C.',
                  ),
                if (vm.todaysReading case final reading?)
                  Padding(
                    key: HomeKeys.todaysReading,
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text("Today's reading: ${reading.celsius} °C"),
                  ),
              ],
            ),
          ),
          _FactCard(vm: vm),
          AppCard(
            icon: Icons.edit_note_rounded,
            title: 'Your day',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (vm.todaysLog case final log?)
                  Text(key: HomeKeys.todaysLog, 'Today: ${logSummary(log)}')
                else
                  const Text('Nothing logged for today yet.'),
                const SizedBox(height: Space.md),
                FilledButton.tonalIcon(
                  key: HomeKeys.logDay,
                  onPressed: () => context.read<ShellTabs>().show(ShellTab.log),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Log flow, symptoms and pain'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _describe(RepositoryError error) => switch (error) {
    RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
    RepositoryError.loadFailed =>
      'Your data could not be loaded from your pod.',
    RepositoryError.malformed => 'The data on your pod could not be read.',
    RepositoryError.newerVersion =>
      'The data on your pod comes from a newer version of Lilith. '
          'Update the app.',
    RepositoryError.saveFailed =>
      'Your change is kept here but could not be saved to your pod.',
    RepositoryError.notLoaded => 'Your data has not loaded yet.',
  };
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.prediction;
    return Row(
      key: HomeKeys.stats,
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
        Expanded(
          child: StatTile(
            key: HomeKeys.avgPeriod,
            icon: Icons.water_drop_outlined,
            label: 'Avg period',
            value: switch (p.averagePeriodLength) {
              final d? => '${d.toStringAsFixed(1)} days',
              null => '—',
            },
          ),
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.prediction;
    final days = vm.daysUntilNextPeriod;
    return AppCard(
      key: HomeKeys.prediction,
      icon: Icons.favorite_rounded,
      title: 'Next period',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (days != null && p.predictedNextPeriod != null) ...[
            Text(
              key: HomeKeys.daysUntil,
              _daysText(days, p.predictedNextPeriod!),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.sm),
          ],
          if (p.lastPeriodStart case final start?) ...[
            Text(
              key: HomeKeys.lastPeriod,
              'Cycle day ${p.currentCycleDay}, since ${_date(start)}',
            ),
            const SizedBox(height: Space.sm),
          ],
          Text(vm.howText(p)),
        ],
      ),
    );
  }

  String _daysText(int days, DateTime date) => switch (days) {
    0 => 'Your period is expected today',
    1 => 'Your period is expected tomorrow',
    < 0 => 'Your period was expected ${-days} days ago, on ${_date(date)}',
    _ => 'Next period in $days days, around ${_date(date)}',
  };

  String _date(DateTime d) => formatShortDate(d, today: vm.today);
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) => AppCard(
    key: HomeKeys.forecast,
    icon: Icons.insights_rounded,
    title: 'Your forecast for the week',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vm.forecastSummary),
        if (vm.forecast.likely.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final l in vm.forecast.likely.take(5))
                LabelBadge(text: '${l.symptom.label} ${l.percent}%'),
            ],
          ),
        ],
      ],
    ),
  );
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fact = vm.fact;
    final openUrl = context.read<UrlOpener>();
    return AppCard(
      key: HomeKeys.fact,
      tone: CardTone.callout,
      icon: Icons.auto_awesome_rounded,
      title: "Today's health fact",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fact.text),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ActionChip(
              key: HomeKeys.factSource,
              avatar: const Icon(Icons.open_in_new_rounded),
              label: Text(fact.source.name),
              onPressed: () => openUrl(Uri.parse(fact.source.url)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app was opened from an invite link: offer to add the sharer.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.now});

  final ShareInvite invite;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ReceivedShareRepository>();
    return AppCard(
      key: HomeKeys.invite,
      icon: Icons.people_outline_rounded,
      title: 'Someone is sharing with you',
      tone: CardTone.highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invite.sharerWebId),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              FilledButton.icon(
                key: HomeKeys.acceptInvite,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: repo,
                      child: ReceivedScreen(now: now, prefill: invite),
                    ),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Add them'),
              ),
              TextButton(
                key: HomeKeys.dismissInvite,
                onPressed: repo.clearInvite,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nothing logged yet: where the user is in their cycle, in one tap.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) => AppCard(
    key: HomeKeys.noData,
    icon: Icons.spa_rounded,
    title: 'Welcome',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Where are you in your cycle? Predictions start from your first '
          'period, and daily temperatures sharpen them.',
        ),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          key: HomeKeys.startedToday,
          onPressed: vm.logPeriodStart,
          icon: const Icon(Icons.water_drop_rounded),
          label: const Text('My period started today'),
        ),
        const SizedBox(height: Space.sm),
        FilledButton.tonalIcon(
          key: HomeKeys.midPeriod,
          onPressed: () => _open(context, PeriodFormMode.midPeriod),
          icon: const Icon(Icons.timelapse_rounded),
          label: const Text("I'm in the middle of my period"),
        ),
        const SizedBox(height: Space.sm),
        FilledButton.tonalIcon(
          key: HomeKeys.notBleeding,
          onPressed: () => _open(context, PeriodFormMode.pastPeriod),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Not bleeding now: add my last period'),
        ),
      ],
    ),
  );

  void _open(BuildContext context, PeriodFormMode mode) {
    final repo = context.read<HealthRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: repo,
          child: PeriodFormScreen(mode: mode, now: vm.now),
        ),
      ),
    );
  }
}
