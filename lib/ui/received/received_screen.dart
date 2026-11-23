// Shared with you: who shares their cycle data with this user, a way to open
// each one, and the form to add someone by WebID and, if encrypted, code.

import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/received/received_view_model.dart';
import 'package:lilith/ui/received/shared_person_screen.dart';
import 'package:lilith/ui/share/share_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ReceivedKeys {
  static const Key empty = Key('received.empty');
  static const Key label = Key('received.label');
  static const Key webId = Key('received.webId');
  static const Key webIdProblem = Key('received.webIdProblem');
  static const Key code = Key('received.code');
  static const Key error = Key('received.error');
  static const Key submit = Key('received.submit');
  static Key card(ReceivedShare s) => Key('received.card.${s.sharerWebId}');
  static Key state(ReceivedShare s) => Key('received.state.${s.sharerWebId}');
  static Key open(ReceivedShare s) => Key('received.open.${s.sharerWebId}');
  static Key remove(ReceivedShare s) => Key('received.remove.${s.sharerWebId}');
}

class ReceivedScreen extends StatelessWidget {
  const ReceivedScreen({this.now = DateTime.now, this.prefill, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  /// An invite to start the form from.
  final ShareInvite? prefill;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) {
      final vm = ReceivedViewModel(
        context.read<ReceivedShareRepository>(),
        ownWebId: context.read<SessionRepository>().session?.webId ?? '',
        now: now,
        prefill: prefill,
      );
      // After this build: the first fetch notifies, which a build cannot take.
      Future<void>.microtask(vm.refreshUnseen);
      return vm;
    },
    child: _ReceivedView(now: now),
  );
}

class _ReceivedView extends StatefulWidget {
  const _ReceivedView({required this.now});

  final DateTime Function() now;

  @override
  State<_ReceivedView> createState() => _ReceivedViewState();
}

class _ReceivedViewState extends State<_ReceivedView> {
  final _label = TextEditingController();
  final _webId = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _webId.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReceivedViewModel>();
    final theme = Theme.of(context);
    if (vm.label != _label.text) _label.text = vm.label;
    if (vm.webId != _webId.text) _webId.text = vm.webId;
    if (vm.code != _code.text) _code.text = vm.code;
    return PageScaffold(
      title: 'Shared with you',
      onRefresh: vm.refreshAll,
      children: [
        const Text(
          'Someone who shares their cycle data with you gives you their '
          'WebID and, if the share is encrypted, a code. You read it from '
          'their pod; nothing is copied to yours.',
        ),
        const SectionHeading('Sharing with you'),
        if (vm.received.isEmpty)
          Text(
            key: ReceivedKeys.empty,
            'Nobody yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final share in vm.received)
          AppCard(
            key: ReceivedKeys.card(share),
            icon: Icons.person_outline_rounded,
            title: share.label,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.sharerWebId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  key: ReceivedKeys.state(share),
                  vm.hasEnded(share)
                      ? 'Ended. They have stopped sharing with you.'
                      : vm.stateText(share),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    FilledButton.tonalIcon(
                      key: ReceivedKeys.open(share),
                      onPressed: () => _open(context, share),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('View'),
                    ),
                    TextButton.icon(
                      key: ReceivedKeys.remove(share),
                      onPressed: () => vm.remove(share),
                      icon: const Icon(Icons.person_remove_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SectionHeading('Add someone'),
        TextField(
          key: ReceivedKeys.label,
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'What you call them',
            hintText: 'e.g. Elric',
          ),
          textInputAction: TextInputAction.next,
          onChanged: vm.setLabel,
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: ReceivedKeys.webId,
          controller: _webId,
          decoration: const InputDecoration(
            labelText: 'Their WebID',
            hintText: 'https://…/profile/card#me',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onChanged: vm.setWebId,
        ),
        if (vm.webId.isNotEmpty)
          if (vm.webIdProblem case final problem?)
            ProblemText(
              key: ReceivedKeys.webIdProblem,
              _describeProblem(problem),
            ),
        const SizedBox(height: Space.md),
        TextField(
          key: ReceivedKeys.code,
          controller: _code,
          decoration: const InputDecoration(
            labelText: 'Their code, if they gave you one',
            hintText: 'XXXX-XXXX-XXXX-XXXX',
          ),
          autocorrect: false,
          onChanged: vm.setCode,
        ),
        if (vm.error case final error?)
          ProblemText(key: ReceivedKeys.error, describeReceivedError(error)),
        const SizedBox(height: Space.xl),
        FilledButton.icon(
          key: ReceivedKeys.submit,
          onPressed: vm.canAdd ? vm.add : null,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: Text(vm.isBusy ? 'Checking…' : 'Add'),
        ),
      ],
    );
  }

  void _open(BuildContext context, ReceivedShare share) {
    final repo = context.read<ReceivedShareRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: repo,
          child: SharedPersonScreen(share: share, now: widget.now),
        ),
      ),
    );
  }

  String _describeProblem(WebIdProblem problem) => switch (problem) {
    WebIdProblem.empty => 'Enter their WebID.',
    WebIdProblem.notALink => 'A WebID is a link, like https://…/card#me.',
    WebIdProblem.yourOwn => 'That is your own WebID.',
  };
}
