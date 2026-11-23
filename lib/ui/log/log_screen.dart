// The day's log: flow, pain and symptoms for one date, saved together.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/log/log_view_model.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class LogKeys {
  static const Key date = Key('log.date');
  static const Key back = Key('log.back');
  static const Key forward = Key('log.forward');
  static const Key pain = Key('log.pain');
  static const Key clearPain = Key('log.clearPain');
  static const Key save = Key('log.save');
  static const Key clear = Key('log.clear');
  static const Key saved = Key('log.saved');
  static const Key error = Key('log.error');
  static const Key dismissError = Key('log.dismissError');
  static Key flow(FlowIntensity f) => Key('log.flow.${f.name}');
  static Key symptom(Symptom s) => Key('log.symptom.${s.name}');
}

class LogScreen extends StatelessWidget {
  const LogScreen({this.now = DateTime.now, this.date, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  /// The day to open on; today when omitted.
  final DateTime? date;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        LogViewModel(context.read<HealthRepository>(), now: now, date: date),
    child: const _LogView(),
  );
}

class _LogView extends StatefulWidget {
  const _LogView();

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  int _seenRequest = 0;

  // Another tab asked for a day: move there once this frame is done.
  void _follow(ShellTabs tabs, LogViewModel vm) {
    if (tabs.logRequest == _seenRequest) return;
    _seenRequest = tabs.logRequest;
    final day = tabs.logDate;
    if (day == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) vm.pickDate(day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LogViewModel>();
    _follow(context.watch<ShellTabs>(), vm);
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Your day',
      actions: const [AppMenu()],
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: LogKeys.error,
            message: _describe(error),
            dismissKey: LogKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        _DayPicker(vm: vm),
        const SectionHeading('Flow'),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final f in FlowIntensity.values)
              ChoiceChip(
                key: LogKeys.flow(f),
                label: Text(_capitalise(f.name)),
                selected: vm.flow == f,
                onSelected: (_) => vm.setFlow(f),
              ),
          ],
        ),
        const SectionHeading('Pain'),
        Row(
          children: [
            Expanded(
              child: Slider(
                key: LogKeys.pain,
                value: (vm.pain ?? 0).toDouble(),
                max: 10,
                divisions: 10,
                label: '${vm.pain ?? 0}',
                onChanged: (v) => vm.setPain(v.round()),
              ),
            ),
            SizedBox(
              width: Space.xxl * 2 + Space.sm,
              child: Text(
                vm.pain == null ? 'Not rated' : '${vm.pain}/10',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if (vm.pain != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: LogKeys.clearPain,
              onPressed: () => vm.setPain(null),
              child: const Text('No pain rating'),
            ),
          ),
        const SectionHeading('Symptoms'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final s in Symptom.values)
              FilterChip(
                key: LogKeys.symptom(s),
                label: Text(s.label),
                selected: vm.symptoms.contains(s),
                onSelected: (_) => vm.toggleSymptom(s),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        FilledButton(
          key: LogKeys.save,
          onPressed: vm.isDirty && !vm.isSaving ? vm.save : null,
          child: Text(vm.isSaving ? 'Saving…' : 'Save my day'),
        ),
        TextButton(
          key: LogKeys.clear,
          onPressed: vm.isEmpty ? null : vm.clear,
          child: const Text('Clear the day'),
        ),
        if (vm.isSavedAsIs)
          Text(
            key: LogKeys.saved,
            'Saved to your pod.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  String _describe(RepositoryError error) => switch (error) {
    RepositoryError.saveFailed =>
      'Your change is kept here but could not be saved to your pod.',
    RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
    _ => 'Your data could not be read from your pod.',
  };
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.vm});

  final LogViewModel vm;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.date,
      firstDate: DateTime(2015),
      lastDate: vm.today,
    );
    if (picked != null) vm.pickDate(picked);
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        key: LogKeys.back,
        tooltip: 'Previous day',
        icon: const Icon(Icons.chevron_left),
        onPressed: vm.goBack,
      ),
      TextButton(
        key: LogKeys.date,
        onPressed: () => _pick(context),
        child: Text(vm.dateLabel),
      ),
      IconButton(
        key: LogKeys.forward,
        tooltip: 'Next day',
        icon: const Icon(Icons.chevron_right),
        onPressed: vm.canGoForward ? vm.goForward : null,
      ),
    ],
  );
}

String _capitalise(String s) => s[0].toUpperCase() + s.substring(1);
