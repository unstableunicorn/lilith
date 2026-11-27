// The app was opened from an invite link: offer to add the sharer.

import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class InviteKeys {
  static const Key card = Key('home.invite');
  static const Key accept = Key('home.acceptInvite');
  static const Key dismiss = Key('home.dismissInvite');
}

class InviteCard extends StatelessWidget {
  const InviteCard({required this.invite, required this.now, super.key});

  final ShareInvite invite;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ReceivedShareRepository>();
    return AppCard(
      key: InviteKeys.card,
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
                key: InviteKeys.accept,
                onPressed: () =>
                    openReceived(context, now: now, prefill: invite),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Add them'),
              ),
              TextButton(
                key: InviteKeys.dismiss,
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

/// Opens the list of people who share with this person, over the tabs. A
/// page of its own, so it gets the repository by hand.
void openReceived(
  BuildContext context, {
  required DateTime Function() now,
  ShareInvite? prefill,
}) {
  final repo = context.read<ReceivedShareRepository>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: repo,
        child: ReceivedScreen(now: now, prefill: prefill),
      ),
    ),
  );
}
