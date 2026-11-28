// The day's log: flow, pain, symptoms and an ovulation test for one date,
// saved together.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/tags.dart';
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
  static const Key miscarriage = Key('log.miscarriage');
  static Key ovulationTest(OvulationTest? t) =>
      Key('log.ovulationTest.${t?.name ?? 'none'}');

  /// A group's heading, there only while the group shows.
  static Key group(LogGroup g) => Key('log.group.${g.name}');
  static Key mood(Mood m) => Key('log.mood.${m.name}');
  static Key tag(String t) => Key('log.tag.$t');
  static const Key tagField = Key('log.tagField');
  static const Key addTag = Key('log.addTag');
  static Key digestion(Digestion d) => Key('log.digestion.${d.name}');
  static Key skin(SkinSign s) => Key('log.skin.${s.name}');
  static Key sleep(SleepQuality? s) => Key('log.sleep.${s?.name ?? 'none'}');
  static Key discharge(Discharge? d) =>
      Key('log.discharge.${d?.name ?? 'none'}');
  static Key pregnancyTest(PregnancyTest? t) =>
      Key('log.pregnancyTest.${t?.name ?? 'none'}');
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
        if (vm.shows(LogGroup.moods))
          _Many<Mood>(
            group: LogGroup.moods,
            values: Mood.values,
            label: (m) => m.label,
            keyFor: LogKeys.mood,
            chosen: vm.signs.moods,
            onToggle: vm.toggleMood,
          ),
        if (vm.shows(LogGroup.sleep))
          _One<SleepQuality>(
            group: LogGroup.sleep,
            values: SleepQuality.values,
            none: 'Not logged',
            label: (s) => s.label,
            keyFor: LogKeys.sleep,
            chosen: vm.signs.sleep,
            onChoose: vm.setSleep,
          ),
        if (vm.shows(LogGroup.digestion))
          _Many<Digestion>(
            group: LogGroup.digestion,
            values: Digestion.values,
            label: (d) => d.label,
            keyFor: LogKeys.digestion,
            chosen: vm.signs.digestion,
            onToggle: vm.toggleDigestion,
          ),
        if (vm.shows(LogGroup.skin))
          _Many<SkinSign>(
            group: LogGroup.skin,
            values: SkinSign.values,
            label: (s) => s.label,
            keyFor: LogKeys.skin,
            chosen: vm.signs.skin,
            onToggle: vm.toggleSkin,
          ),
        if (vm.shows(LogGroup.discharge))
          _One<Discharge>(
            group: LogGroup.discharge,
            values: Discharge.values,
            none: 'Not logged',
            label: (d) => d.label,
            keyFor: LogKeys.discharge,
            chosen: vm.signs.discharge,
            onChoose: vm.setDischarge,
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
        if (vm.shows(LogGroup.pregnancyTest))
          _One<PregnancyTest>(
            group: LogGroup.pregnancyTest,
            values: PregnancyTest.values,
            none: 'Not taken',
            label: (t) => t.label,
            keyFor: LogKeys.pregnancyTest,
            chosen: vm.signs.pregnancyTest,
            onChoose: vm.setPregnancyTest,
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
        if (vm.shows(LogGroup.tags))
          _Tags(
            chosen: vm.signs.tags,
            suggestions: vm.tagSuggestions,
            onAdd: vm.addTag,
            onRemove: vm.removeTag,
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

/// A group where several values can apply to a day: a chip each.
class _Many<T> extends StatelessWidget {
  const _Many({
    required this.group,
    required this.values,
    required this.label,
    required this.keyFor,
    required this.chosen,
    required this.onToggle,
  });

  final LogGroup group;
  final List<T> values;
  final String Function(T) label;
  final Key Function(T) keyFor;
  final Set<T> chosen;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(key: LogKeys.group(group), group.label),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          for (final v in values)
            FilterChip(
              key: keyFor(v),
              label: Text(label(v)),
              selected: chosen.contains(v),
              onSelected: (_) => onToggle(v),
            ),
        ],
      ),
    ],
  );
}

/// The person's own tags: the day's as chosen chips, past ones to tap, and
/// a field for a new one. Holds only the text being typed.
class _Tags extends StatefulWidget {
  const _Tags({
    required this.chosen,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> chosen;
  final List<String> Function(String typed) suggestions;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_Tags> createState() => _TagsState();
}

class _TagsState extends State<_Tags> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _add() {
    widget.onAdd(_typed.text);
    _typed.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(key: LogKeys.group(LogGroup.tags), LogGroup.tags.label),
      ListenableBuilder(
        listenable: _typed,
        builder: (context, _) => Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final t in widget.chosen)
              FilterChip(
                key: LogKeys.tag(t),
                label: Text(t),
                selected: true,
                onSelected: (_) => widget.onRemove(t),
              ),
            for (final t in widget.suggestions(_typed.text))
              FilterChip(
                key: LogKeys.tag(t),
                label: Text(t),
                selected: false,
                onSelected: (_) => widget.onAdd(t),
              ),
          ],
        ),
      ),
      const SizedBox(height: Space.sm),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: LogKeys.tagField,
              controller: _typed,
              maxLength: maxTagLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(
                labelText: 'A tag of your own',
                hintText: 'Travel, night shift…',
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          FilledButton.tonal(
            key: LogKeys.addTag,
            onPressed: _add,
            child: const Text('Add'),
          ),
        ],
      ),
    ],
  );
}

/// A group with one value a day, or none: a chip each, [none] first.
class _One<T extends Object> extends StatelessWidget {
  const _One({
    required this.group,
    required this.values,
    required this.none,
    required this.label,
    required this.keyFor,
    required this.chosen,
    required this.onChoose,
  });

  final LogGroup group;
  final List<T> values;
  final String none;
  final String Function(T) label;
  final Key Function(T?) keyFor;
  final T? chosen;
  final ValueChanged<T?> onChoose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading(key: LogKeys.group(group), group.label),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          for (final T? v in [null, ...values])
            ChoiceChip(
              key: keyFor(v),
              label: Text(v == null ? none : label(v)),
              selected: chosen == v,
              onSelected: (_) => onChoose(v),
            ),
        ],
      ),
    ],
  );
}
