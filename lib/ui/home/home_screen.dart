// The signed-in landing screen: today's prediction and the two quick logs.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/cycle_predictor.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/home/home_view_model.dart';
import 'package:lilith/ui/log/log_screen.dart';
import 'package:lilith/ui/log/log_summary.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class HomeKeys {
  static const Key webId = Key('home.webId');
  static const Key manage = Key('home.manage');
  static const Key logout = Key('home.logout');
  static const Key loading = Key('home.loading');
  static const Key error = Key('home.error');
  static const Key dismissError = Key('home.dismissError');
  static const Key noData = Key('home.noData');
  static const Key prediction = Key('home.prediction');
  static const Key daysUntil = Key('home.daysUntil');
  static const Key lastPeriod = Key('home.lastPeriod');
  static const Key logPeriod = Key('home.logPeriod');
  static const Key temperature = Key('home.temperature');
  static const Key logTemperature = Key('home.logTemperature');
  static const Key temperatureProblem = Key('home.temperatureProblem');
  static const Key todaysReading = Key('home.todaysReading');
  static const Key logDay = Key('home.logDay');
  static const Key todaysLog = Key('home.todaysLog');
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
    final session = context.watch<SessionRepository>();
    final vm = context.watch<HomeViewModel>();
    final openUrl = context.read<UrlOpener>();
    final current = session.session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lilith'),
        actions: [
          IconButton(
            key: HomeKeys.logout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: session.logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vm.error case final error?)
            MaterialBanner(
              key: HomeKeys.error,
              content: Text(_describe(error)),
              actions: [
                TextButton(
                  key: HomeKeys.dismissError,
                  onPressed: vm.clearError,
                  child: const Text('OK'),
                ),
              ],
            ),
          if (!vm.isLoaded)
            const Center(
              key: HomeKeys.loading,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (!vm.hasData)
              const Text(
                key: HomeKeys.noData,
                'Log the day your period starts to begin predicting. Daily '
                'temperature readings sharpen the estimate.',
              )
            else
              _PredictionCard(vm: vm),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: HomeKeys.logPeriod,
              onPressed: vm.logPeriodStart,
              icon: const Icon(Icons.water_drop),
              label: const Text('My period started today'),
            ),
            const SizedBox(height: 16),
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
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: HomeKeys.logTemperature,
                  onPressed: () => _logTemperature(vm),
                  child: const Text('Log'),
                ),
              ],
            ),
            if (_temperatureRefused)
              Padding(
                key: HomeKeys.temperatureProblem,
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Enter a body temperature between '
                  '${HomeViewModel.minCelsius} and ${HomeViewModel.maxCelsius} °C.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (vm.todaysReading case final reading?)
              Padding(
                key: HomeKeys.todaysReading,
                padding: const EdgeInsets.only(top: 8),
                child: Text("Today's reading: ${reading.celsius} °C"),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              key: HomeKeys.logDay,
              onPressed: () => _openLog(context, vm),
              icon: const Icon(Icons.edit_note),
              label: const Text('Log flow, symptoms and pain'),
            ),
            if (vm.todaysLog case final log?)
              Padding(
                key: HomeKeys.todaysLog,
                padding: const EdgeInsets.only(top: 8),
                child: Text('Today: ${logSummary(log)}'),
              ),
          ],
          const SizedBox(height: 32),
          const Text('Logged in as'),
          SelectableText(key: HomeKeys.webId, current?.webId ?? ''),
          if (current != null)
            TextButton(
              key: HomeKeys.manage,
              onPressed: () => openUrl(current.provider.manageUrl),
              child: Text('Manage your pod at ${current.provider.name}'),
            ),
        ],
      ),
    );
  }

  /// The log screen is a route of its own, so it gets the repository by hand.
  void _openLog(BuildContext context, HomeViewModel vm) {
    final repo = context.read<HealthRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: repo,
          child: LogScreen(now: vm.now),
        ),
      ),
    );
  }

  String _describe(RepositoryError error) => switch (error) {
    RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
    RepositoryError.loadFailed =>
      'Your data could not be loaded from your pod.',
    RepositoryError.malformed => 'The data on your pod could not be read.',
    RepositoryError.newerVersion => 'The data on your pod comes from a newer version of Lilith. Update the app.',
    RepositoryError.saveFailed =>
      'Your change is kept here but could not be saved to your pod.',
    RepositoryError.notLoaded => 'Your data has not loaded yet.',
  };
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.vm});

  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = vm.prediction;
    final days = vm.daysUntilNextPeriod;
    return Card(
      key: HomeKeys.prediction,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (p.lastPeriodStart case final start?)
              Text(
                key: HomeKeys.lastPeriod,
                'Cycle day ${p.currentCycleDay}, since ${_date(start)}',
              ),
            if (days != null && p.predictedNextPeriod != null) ...[
              const SizedBox(height: 8),
              Text(
                key: HomeKeys.daysUntil,
                _daysText(days, p.predictedNextPeriod!),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
            const SizedBox(height: 8),
            Text(_how(p)),
          ],
        ),
      ),
    );
  }

  String _daysText(int days, DateTime date) => switch (days) {
    0 => 'Your period is expected today',
    1 => 'Your period is expected tomorrow',
    < 0 => 'Your period was expected ${-days} days ago, on ${_date(date)}',
    _ => 'Next period in $days days, around ${_date(date)}',
  };

  String _how(CyclePrediction p) => switch (p.method) {
    PredictionMethod.temperatureShift =>
      'A sustained temperature rise around ${_date(p.estimatedOvulation!)} '
          'suggests ovulation; a ${p.lutealLength}-day luteal phase follows.',
    PredictionMethod.cycleAverage when p.cycleCount == 0 =>
      'Only one period logged, so this assumes a typical '
          '${CyclePredictor.defaultCycleLength}-day cycle.',
    PredictionMethod.cycleAverage =>
      'Based on your average cycle of '
          '${p.averageCycleLength!.toStringAsFixed(1)} days over '
          '${p.cycleCount} recorded ${p.cycleCount == 1 ? 'cycle' : 'cycles'}.',
    PredictionMethod.insufficientData => 'Not enough data yet.',
  };

  String _date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}${d.year == DateTime.now().year ? '' : ' ${d.year}'}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
