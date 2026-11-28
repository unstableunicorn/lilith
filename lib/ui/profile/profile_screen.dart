// The health profile: conditions, treatments and notes, kept for the user's
// own reference, saved together.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/life_factor_text.dart';
import 'package:lilith/ui/profile/profile_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ProfileKeys {
  static const Key error = Key('profile.error');
  static const Key dismissError = Key('profile.dismissError');
  static const Key notes = Key('profile.notes');
  static const Key save = Key('profile.save');
  static const Key saved = Key('profile.saved');
  static Key condition(ReproductiveCondition c) =>
      Key('profile.condition.${c.name}');
  static Key treatment(FertilityTreatment t) =>
      Key('profile.treatment.${t.name}');
  static Key contraception(Contraception c) =>
      Key('profile.contraception.${c.name}');
  static Key regularity(CycleRegularity r) =>
      Key('profile.regularity.${r.name}');
  static const Key birthYear = Key('profile.birthYear');
  static Key history(String field) => Key('profile.history.$field');
  static Key startFactor(LifeFactorKind k) =>
      Key('profile.startFactor.${k.name}');

  /// The [i]th life factor's card and its buttons, oldest first.
  static Key factor(int i) => Key('profile.factor.$i');
  static Key factorStart(int i) => Key('profile.factor.$i.start');
  static Key factorDue(int i) => Key('profile.factor.$i.due');
  static Key endFactor(int i) => Key('profile.factor.$i.end');
  static Key removeFactor(int i) => Key('profile.factor.$i.remove');

  /// What the life factors do, said above them.
  static const Key factorsNote = Key('profile.factorsNote');

  /// The [i]th miscarriage day, oldest first, and its remove button.
  static Key miscarriage(int i) => Key('profile.miscarriage.$i');
  static Key removeMiscarriage(int i) => Key('profile.miscarriage.$i.remove');
  static const Key addMiscarriage = Key('profile.addMiscarriage');
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        ProfileViewModel(context.read<HealthRepository>(), now: now),
    child: const _ProfileView(),
  );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  late final TextEditingController _notes;
  late final TextEditingController _birthYear;
  late final Map<String, TextEditingController> _history;
  bool _savedHere = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<ProfileViewModel>();
    _notes = TextEditingController(text: vm.notes);
    _birthYear = TextEditingController(text: vm.birthYear?.toString() ?? '');
    final h = vm.history;
    _history = {
      'pregnancies': TextEditingController(
        text: h.pregnancies?.toString() ?? '',
      ),
      'births': TextEditingController(text: h.births?.toString() ?? ''),
      'miscarriages': TextEditingController(
        text: h.miscarriages?.toString() ?? '',
      ),
      'lastPregnancyYear': TextEditingController(
        text: h.lastPregnancyYear?.toString() ?? '',
      ),
    };
  }

  @override
  void dispose() {
    _notes.dispose();
    _birthYear.dispose();
    for (final c in _history.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(ProfileViewModel vm) async {
    await vm.save();
    if (mounted) setState(() => _savedHere = vm.error == null);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Your health profile',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: ProfileKeys.error,
            message: _describe(error),
            dismissKey: ProfileKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        const Text(
          'For your own reference, and for anyone you choose to share with. '
          'Kept on your pod like everything else.',
        ),
        const SectionHeading('Conditions'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final c in ReproductiveCondition.values)
              FilterChip(
                key: ProfileKeys.condition(c),
                label: Text(c.label),
                selected: vm.conditions.contains(c),
                onSelected: (_) => vm.toggleCondition(c),
              ),
          ],
        ),
        const SectionHeading('Treatments and contraception'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final t in FertilityTreatment.values)
              FilterChip(
                key: ProfileKeys.treatment(t),
                label: Text(t.label),
                selected: vm.treatments.contains(t),
                onSelected: (_) => vm.toggleTreatment(t),
              ),
          ],
        ),
        const SectionHeading('Contraception'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final c in Contraception.values)
              ChoiceChip(
                key: ProfileKeys.contraception(c),
                label: Text(c.label),
                selected: vm.contraception == c,
                onSelected: (_) => vm.setContraception(c),
              ),
          ],
        ),
        const SectionHeading('How regular are your cycles?'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final r in CycleRegularity.values)
              ChoiceChip(
                key: ProfileKeys.regularity(r),
                label: Text(r.label),
                selected: vm.regularity == r,
                onSelected: (_) => vm.setRegularity(r),
              ),
          ],
        ),
        const SectionHeading('About you (optional)'),
        TextField(
          key: ProfileKeys.birthYear,
          controller: _birthYear,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Year of birth'),
          onChanged: vm.setBirthYear,
        ),
        const SectionHeading('Pregnancy and breastfeeding'),
        const Text(
          'While you are pregnant or breastfeeding, or after a miscarriage, '
          'predictions and the fertile window pause. Anyone you share your '
          'cycle data with sees why.',
        ),
        const SizedBox(height: Space.sm),
        for (final (i, f) in vm.lifeFactors.indexed)
          _FactorCard(index: i, factor: f, vm: vm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final k in LifeFactorKind.values)
              ActionChip(
                key: ProfileKeys.startFactor(k),
                avatar: const Icon(Icons.add_rounded),
                label: Text(k.label),
                onPressed: () => vm.startFactor(k),
              ),
          ],
        ),
        const SectionHeading('Pregnancies (optional)'),
        for (final (field, label) in const [
          ('pregnancies', 'Pregnancies in all'),
          ('births', 'Births'),
          ('miscarriages', 'Miscarriages'),
          ('lastPregnancyYear', 'Year of the last pregnancy'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: TextField(
              key: ProfileKeys.history(field),
              controller: _history[field],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: label),
              onChanged: (text) => vm.setHistory(field, text),
            ),
          ),
        const SectionHeading('Notes'),
        TextField(
          key: ProfileKeys.notes,
          controller: _notes,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'e.g. medications, what your doctor has said…',
          ),
          onChanged: vm.setNotes,
        ),
        const SizedBox(height: Space.xl),
        FilledButton(
          key: ProfileKeys.save,
          onPressed: vm.isDirty && !vm.isSaving ? () => _save(vm) : null,
          child: Text(vm.isSaving ? 'Saving…' : 'Save profile'),
        ),
        if (_savedHere && !vm.isDirty)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              key: ProfileKeys.saved,
              'Saved to your pod.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
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

/// One life factor: its line, and while it is open the buttons that date
/// and end it. Dates are picked here and handed to the view model.
class _FactorCard extends StatelessWidget {
  const _FactorCard({
    required this.index,
    required this.factor,
    required this.vm,
  });

  final int index;
  final LifeFactor factor;
  final ProfileViewModel vm;

  Future<void> _pickStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: factor.start,
      firstDate: DateTime(vm.today.year - 3),
      lastDate: vm.today,
    );
    if (picked != null) vm.setFactorStart(factor, picked);
  }

  Future<void> _pickDue(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: switch (factor.dueDate) {
        final d? when !d.isBefore(vm.today) => d,
        _ => vm.today,
      },
      firstDate: vm.today,
      lastDate: DateTime(vm.today.year + 1, vm.today.month, vm.today.day),
    );
    if (picked != null) vm.setFactorDue(factor, picked);
  }

  @override
  Widget build(BuildContext context) {
    final open = factor.end == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        key: ProfileKeys.factor(index),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              factorLine(factor, today: vm.today),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: Space.sm,
              children: [
                if (open)
                  TextButton(
                    key: ProfileKeys.factorStart(index),
                    onPressed: () => _pickStart(context),
                    child: const Text('Change the start'),
                  ),
                if (open && factor.kind == LifeFactorKind.pregnant)
                  TextButton(
                    key: ProfileKeys.factorDue(index),
                    onPressed: () => _pickDue(context),
                    child: Text(
                      factor.dueDate == null
                          ? 'Set the due date'
                          : 'Change the due date',
                    ),
                  ),
                if (open)
                  TextButton(
                    key: ProfileKeys.endFactor(index),
                    onPressed: () => vm.endFactor(factor),
                    child: const Text('It has ended'),
                  ),
                TextButton(
                  key: ProfileKeys.removeFactor(index),
                  onPressed: () => vm.removeFactor(factor),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
