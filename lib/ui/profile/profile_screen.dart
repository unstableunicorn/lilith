// The health profile: conditions, treatments and notes, kept for the user's
// own reference, saved together.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/ui/components/components.dart';
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
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ProfileViewModel(context.read<HealthRepository>()),
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
  bool _savedHere = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(
      text: context.read<ProfileViewModel>().notes,
    );
  }

  @override
  void dispose() {
    _notes.dispose();
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
