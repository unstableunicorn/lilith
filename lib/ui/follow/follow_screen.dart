// Today for someone who follows: the person who shares with them, their
// next period and calendar, and a chooser when several people share.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/repository_errors.dart';
import 'package:lilith/ui/follow/follow_view_model.dart';
import 'package:lilith/ui/received/invite_card.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class FollowKeys {
  static const Key loading = Key('follow.loading');
  static const Key error = Key('follow.error');
  static const Key dismissError = Key('follow.dismissError');
  static const Key empty = Key('follow.empty');
  static const Key add = Key('follow.add');
  static const Key chooser = Key('follow.chooser');
  static Key person(String webId) => Key('follow.person.$webId');
  static const Key card = Key('follow.card');
  static const Key open = Key('follow.open');
  static const Key cardProblem = Key('follow.cardProblem');
}

class FollowScreen extends StatelessWidget {
  const FollowScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => FollowViewModel(context.read<HealthRepository>()),
    child: _FollowView(now: now),
  );
}

class _FollowView extends StatelessWidget {
  const _FollowView({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FollowViewModel>();
    final received = context.watch<ReceivedShareRepository>();
    final followed = vm.followed;
    return PageScaffold(
      title: 'Lilith',
      onRefresh: followed == null ? null : () => received.refresh(followed),
      actions: const [AppMenu()],
      children: [
        if (received.pendingInvite case final invite?)
          InviteCard(invite: invite, now: now),
        if (vm.error case final error?)
          NoticeBanner(
            key: FollowKeys.error,
            message: describeRepositoryError(error),
            dismissKey: FollowKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        if (vm.isWaiting)
          const BusyIndicator(key: FollowKeys.loading, label: 'Loading')
        else if (!vm.isLoaded)
          const SizedBox.shrink()
        else if (followed == null)
          _NobodyCard(now: now)
        else ...[
          if (vm.showsChooser) PersonChooser(vm: vm),
          // A new person is a new view model, and a fetch of their copy.
          SharedPersonScope(
            key: ValueKey(followed.sharerWebId),
            share: followed,
            now: now,
            child: const SharedPersonBody(),
          ),
        ],
      ],
    );
  }
}

/// Nobody shares with this person yet: how that starts.
class _NobodyCard extends StatelessWidget {
  const _NobodyCard({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => AppCard(
    key: FollowKeys.empty,
    icon: Icons.people_outline_rounded,
    title: 'Nobody shares with you yet',
    tone: CardTone.highlight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ask the person you follow to share with you from the Pod tab of '
          'their Lilith. Open the link they send you, or add them here with '
          'their WebID and the code they give you.',
        ),
        const SizedBox(height: Space.sm),
        FilledButton.icon(
          key: FollowKeys.add,
          onPressed: () => openReceived(context, now: now),
          icon: const Icon(Icons.person_add_alt_rounded),
          label: const Text('Add someone'),
        ),
      ],
    ),
  );
}

/// One chip per person who shares; the one showing is selected.
class PersonChooser extends StatelessWidget {
  const PersonChooser({required this.vm, super.key});

  final FollowViewModel vm;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Wrap(
      key: FollowKeys.chooser,
      spacing: Space.sm,
      children: [
        for (final person in vm.people)
          ChoiceChip(
            key: FollowKeys.person(person.sharerWebId),
            label: Text(person.label),
            selected: person.sharerWebId == vm.followed?.sharerWebId,
            onSelected: (_) => vm.follow(person),
          ),
      ],
    ),
  );
}
