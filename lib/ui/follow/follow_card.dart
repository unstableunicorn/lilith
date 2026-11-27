// On Today, for someone who tracks their own cycle and also follows: the
// followed person's next period, and the way to the rest of what they share.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/follow/follow_screen.dart';
import 'package:lilith/ui/follow/follow_view_model.dart';
import 'package:lilith/ui/received/invite_card.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:lilith/ui/received/shared_person_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class FollowCard extends StatelessWidget {
  const FollowCard({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => FollowViewModel(context.read<HealthRepository>()),
    child: _Card(now: now),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FollowViewModel>();
    final followed = vm.followed;
    return AppCard(
      key: FollowKeys.card,
      icon: Icons.people_outline_rounded,
      title: followed?.label ?? 'Follow someone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vm.showsChooser) PersonChooser(vm: vm),
          if (followed == null) ...[
            const Text(
              'Nobody shares with you yet. Open the link they send you, or '
              'add them with their WebID and code.',
            ),
            const SizedBox(height: Space.sm),
            TextButton.icon(
              key: FollowKeys.add,
              onPressed: () => openReceived(context, now: now),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add someone'),
            ),
          ] else
            // A new person is a new view model, and a fetch of their copy.
            SharedPersonScope(
              key: ValueKey(followed.sharerWebId),
              share: followed,
              now: now,
              child: _Person(now: now),
            ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.now});

  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final person = context.watch<SharedPersonViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: person.hasProblem ? FollowKeys.cardProblem : null,
          person.headline,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          key: FollowKeys.open,
          onPressed: () {
            final repo = context.read<ReceivedShareRepository>();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                  value: repo,
                  child: SharedPersonScreen(share: person.share, now: now),
                ),
              ),
            );
          },
          icon: const Icon(Icons.visibility_rounded),
          label: const Text('See what they share'),
        ),
      ],
    );
  }
}
