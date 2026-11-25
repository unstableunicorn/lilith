// The day's log: flow, pain, symptoms and an ovulation test for one date,
// saved together.

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
  static const Key periodHint = Key('log.periodHint');
  static Key flow(FlowIntensity f) => Key('log.flow.${f.name}');
  static Key symptom(Symptom s) => Key('log.symptom.${s.name}');
  static const Key note = Key('log.note');
  static const Key dose = Key('log.dose');
  static Key ovulationTest(OvulationTest? t) =>
      Key('log.ovulationTest.${t?.name ?? 'none'}');
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
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  // Typing keeps the two equal; a new day or a cleared draft does not.
  void _syncNote(LogViewModel vm) {
    final want = vm.note ?? '';
    if (_note.text.trim() != want) _note.text = want;
  }

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
    _syncNote(vm);
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
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            key: LogKeys.periodHint,
            'Days with light flow or more become part of your periods; '
            'spotting on its own does not start one.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
        const SectionHeading('Ovulation test'),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final (t, label) in const [
              (null, 'Not taken'),
              (OvulationTest.negative, 'Negative'),
              (OvulationTest.positive, 'Positive'),
            ])
              ChoiceChip(
                key: LogKeys.ovulationTest(t),
                label: Text(label),
                selected: vm.ovulationTest == t,
                onSelected: (_) => vm.setOvulationTest(t),
              ),
          ],
        ),
        if (vm.offersDose)
          SwitchListTile(
            key: LogKeys.dose,
            contentPadding: EdgeInsets.zero,
            title: Text(
              vm.doseIsPatchOrRing ? 'Patch or ring done' : 'Pill taken',
            ),
            value: vm.doseDone,
            onChanged: vm.setDoseDone,
          ),
        const SectionHeading('Note'),
        TextField(
          key: LogKeys.note,
          controller: _note,
          onChanged: vm.setNote,
          minLines: 2,
          maxLines: 6,
          maxLength: DailyLog.maxNoteLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Anything else about today',
            hintText: 'Travel, stress, a new medicine…',
          ),
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
