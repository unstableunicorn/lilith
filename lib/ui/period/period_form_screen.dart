// The period form: the first day, and as applies the last day, the flow and
// the first-time questions about usual lengths and contraception.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/dates.dart';
import 'package:lilith/ui/period/period_form_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class PeriodFormKeys {
  static const Key firstDay = Key('periodForm.firstDay');
  static const Key lastDay = Key('periodForm.lastDay');
  static const Key clearLastDay = Key('periodForm.clearLastDay');
  static const Key cycleLength = Key('periodForm.cycleLength');
  static const Key periodLength = Key('periodForm.periodLength');
  static const Key contraception = Key('periodForm.contraception');
  static const Key save = Key('periodForm.save');
  static const Key error = Key('periodForm.error');
  static const Key dismissError = Key('periodForm.dismissError');
  static Key flow(FlowIntensity f) => Key('periodForm.flow.${f.name}');
  static Key problem(PeriodFormProblem p) =>
      Key('periodForm.problem.${p.name}');
}

class PeriodFormScreen extends StatelessWidget {
  const PeriodFormScreen({
    required this.mode,
    this.editing,
    this.now = DateTime.now,
    super.key,
  });

  final PeriodFormMode mode;

  /// The period being changed, in [PeriodFormMode.edit].
  final PeriodEvent? editing;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => PeriodFormViewModel(
      context.read<HealthRepository>(),
      mode: mode,
      now: now,
      editing: editing,
    ),
    child: const _PeriodFormView(),
  );
}

class _PeriodFormView extends StatelessWidget {
  const _PeriodFormView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PeriodFormViewModel>();
    final theme = Theme.of(context);
    return PageScaffold(
      title: switch (vm.mode) {
        PeriodFormMode.midPeriod => 'Your current period',
        PeriodFormMode.pastPeriod => 'Your last period',
        PeriodFormMode.edit => 'Edit this period',
      },
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: PeriodFormKeys.error,
            message: 'The save did not reach your pod. Try again.',
            detail: error.name,
            dismissKey: PeriodFormKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        Text(switch (vm.mode) {
          PeriodFormMode.midPeriod =>
            'When did it start? Everything else is optional.',
          PeriodFormMode.pastPeriod =>
            'The last period you remember. Only the first day is needed; '
                'the rest sharpens the prediction.',
          PeriodFormMode.edit => 'Change what is known about this period.',
        }),
        const SectionHeading('First day'),
        TextButton.icon(
          key: PeriodFormKeys.firstDay,
          onPressed: () => _pick(context, vm, first: true),
          icon: const Icon(Icons.event_rounded),
          label: Text(switch (vm.firstDay) {
            final d? => formatDay(d),
            null => 'Pick the first day',
          }),
        ),
        if (vm.problems.contains(PeriodFormProblem.noFirstDay) &&
            vm.firstDay == null)
          ProblemText(
            key: PeriodFormKeys.problem(PeriodFormProblem.noFirstDay),
            'The first day is needed.',
          ),
        if (vm.asksLastDay) ...[
          const SectionHeading('Last day (optional)'),
          Wrap(
            spacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: PeriodFormKeys.lastDay,
                onPressed: () => _pick(context, vm, first: false),
                icon: const Icon(Icons.event_available_rounded),
                label: Text(switch (vm.lastDay) {
                  final d? => formatDay(d),
                  null => 'Pick the last day',
                }),
              ),
              if (vm.lastDay != null)
                TextButton(
                  key: PeriodFormKeys.clearLastDay,
                  onPressed: () => vm.setLastDay(null),
                  child: const Text('Not sure'),
                ),
            ],
          ),
          if (vm.problems.contains(PeriodFormProblem.endBeforeStart))
            ProblemText(
              key: PeriodFormKeys.problem(PeriodFormProblem.endBeforeStart),
              'The last day cannot come before the first.',
            ),
        ],
        const SectionHeading('Flow (optional)'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final f in vm.flows)
              ChoiceChip(
                key: PeriodFormKeys.flow(f),
                label: Text(_capitalise(f.name)),
                selected: vm.flow == f,
                onSelected: (on) => vm.setFlow(on ? f : null),
              ),
          ],
        ),
        if (vm.asksAboutYou) ...[
          const SectionHeading('About your cycles (optional)'),
          TextField(
            key: PeriodFormKeys.cycleLength,
            controller: TextEditingController(
              text: vm.usualCycleLength?.toString() ?? '',
            ),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Usual cycle length, in days',
              hintText: 'e.g. 28',
            ),
            onChanged: vm.setUsualCycleLength,
          ),
          if (vm.problems.contains(PeriodFormProblem.cycleLength))
            ProblemText(
              key: PeriodFormKeys.problem(PeriodFormProblem.cycleLength),
              'A cycle is between ${HealthProfile.minCycleLength} and '
              '${HealthProfile.maxCycleLength} days here.',
            ),
          const SizedBox(height: Space.md),
          TextField(
            key: PeriodFormKeys.periodLength,
            controller: TextEditingController(
              text: vm.usualPeriodLength?.toString() ?? '',
            ),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Usual period length, in days',
              hintText: 'e.g. 5',
            ),
            onChanged: vm.setUsualPeriodLength,
          ),
          if (vm.problems.contains(PeriodFormProblem.periodLength))
            ProblemText(
              key: PeriodFormKeys.problem(PeriodFormProblem.periodLength),
              'A period is between ${HealthProfile.minPeriodLength} and '
              '${HealthProfile.maxPeriodLength} days here.',
            ),
          SwitchListTile(
            key: PeriodFormKeys.contraception,
            contentPadding: EdgeInsets.zero,
            title: const Text('I use hormonal contraception'),
            subtitle: const Text(
              'The pill, a hormonal IUD, an implant or injection.',
            ),
            value: vm.hormonalContraception,
            onChanged: vm.setHormonalContraception,
          ),
        ],
        const SizedBox(height: Space.xl),
        FilledButton(
          key: PeriodFormKeys.save,
          onPressed: vm.canSave ? () => _save(context, vm) : null,
          child: Text(vm.isSaving ? 'Saving…' : 'Save'),
        ),
        const SizedBox(height: Space.md),
        Text(
          'Kept on your pod like everything else. Nothing here is shared '
          'unless you choose to share.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    PeriodFormViewModel vm, {
    required bool first,
  }) async {
    final today = vm.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: (first ? vm.firstDay : vm.lastDay) ?? vm.firstDay ?? today,
      firstDate: DateTime(today.year - 3, today.month, today.day),
      lastDate: today,
      helpText: first ? 'First day of the period' : 'Last day of the period',
    );
    if (picked == null) return;
    if (first) {
      vm.setFirstDay(picked);
    } else {
      vm.setLastDay(picked);
    }
  }

  Future<void> _save(BuildContext context, PeriodFormViewModel vm) async {
    final saved = await vm.save();
    if (!saved || !context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  String _capitalise(String s) => s[0].toUpperCase() + s.substring(1);
}
