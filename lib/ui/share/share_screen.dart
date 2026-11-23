// Sharing: who can read the cycle data, read-only, from this pod, and the
// form to add someone. The share's code is shown here and nowhere else.

import 'package:flutter/services.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/share/share_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ShareKeys {
  static const Key error = Key('share.error');
  static const Key dismissError = Key('share.dismissError');
  static const Key created = Key('share.created');
  static const Key createdCode = Key('share.createdCode');
  static const Key copyCode = Key('share.copyCode');
  static const Key dismissCreated = Key('share.dismissCreated');
  static const Key empty = Key('share.empty');
  static const Key label = Key('share.label');
  static const Key webId = Key('share.webId');
  static const Key webIdProblem = Key('share.webIdProblem');
  static const Key submit = Key('share.submit');
  static Key duration(ShareDuration d) => Key('share.duration.${d.name}');
  static Key content(ShareContent c) => Key('share.content.${c.name}');
  static Key range(ExportRange r) => Key('share.range.${r.name}');
  static const Key createdLink = Key('share.createdLink');
  static const Key copyLink = Key('share.copyLink');
  static Key link(Share s) => Key('share.link.${s.id}');
  static Key card(Share s) => Key('share.card.${s.id}');
  static Key end(Share s) => Key('share.end.${s.id}');
  static Key code(Share s) => Key('share.code.${s.id}');
  static Key showCode(Share s) => Key('share.showCode.${s.id}');
  static Key qr(Share s) => Key('share.qr.${s.id}');
  static const Key createdQr = Key('share.createdQr');
  static Key revoke(Share s) => Key('share.revoke.${s.id}');
}

class ShareScreen extends StatelessWidget {
  const ShareScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ShareViewModel(
      context.read<ShareRepository>(),
      ownWebId: context.read<SessionRepository>().session?.webId ?? '',
      now: now,
    ),
    child: const _ShareView(),
  );
}

class _ShareView extends StatefulWidget {
  const _ShareView();

  @override
  State<_ShareView> createState() => _ShareViewState();
}

class _ShareViewState extends State<_ShareView> {
  final _label = TextEditingController();
  final _webId = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _webId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShareViewModel>();
    final theme = Theme.of(context);
    final today = vm.now();
    if (vm.label != _label.text) _label.text = vm.label;
    if (vm.webId != _webId.text) _webId.text = vm.webId;
    return PageScaffold(
      title: 'Sharing',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: ShareKeys.error,
            message: _describe(error),
            detail: vm.errorDetail,
            dismissKey: ShareKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        const Text(
          'Someone you name can read your periods, temperatures and daily '
          'logs, and nothing else, straight from your pod. You can end it '
          'at any time.',
        ),
        if (vm.created case final share?) ...[
          const SizedBox(height: Space.lg),
          _CreatedCard(share: share, vm: vm),
        ],
        const SectionHeading('Sharing with'),
        if (vm.shares.isEmpty)
          Text(
            key: ShareKeys.empty,
            'Nobody yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        for (final share in vm.shares)
          _ShareCard(share: share, vm: vm, today: today),
        const SectionHeading('Share with someone'),
        TextField(
          key: ShareKeys.label,
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'What you call them',
            hintText: 'e.g. Alex, Dr Patel',
          ),
          textInputAction: TextInputAction.next,
          onChanged: vm.setLabel,
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: ShareKeys.webId,
          controller: _webId,
          decoration: const InputDecoration(
            labelText: 'Their WebID',
            hintText: 'https://…/profile/card#me',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: vm.setWebId,
        ),
        if (vm.webId.isNotEmpty)
          if (vm.webIdProblem case final problem?)
            ProblemText(key: ShareKeys.webIdProblem, _describeProblem(problem)),
        const SectionHeading('What they get'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final c in ShareContent.values)
              ChoiceChip(
                key: ShareKeys.content(c),
                label: Text(c.label),
                selected: vm.content == c,
                onSelected: (_) => vm.setContent(c),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            vm.content.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (vm.content == ShareContent.report) ...[
          const SectionHeading('How far back'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final r in ExportRange.values)
                ChoiceChip(
                  key: ShareKeys.range(r),
                  label: Text(r.label),
                  selected: vm.range == r,
                  onSelected: (_) => vm.setRange(r),
                ),
            ],
          ),
        ],
        const SectionHeading('For how long'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final d in ShareDuration.values)
              ChoiceChip(
                key: ShareKeys.duration(d),
                label: Text(d.label),
                selected: vm.duration == d,
                onSelected: (_) => vm.setDuration(d),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        FilledButton.icon(
          key: ShareKeys.submit,
          onPressed: vm.canShare ? vm.share : null,
          icon: const Icon(Icons.person_add_alt_rounded),
          label: Text(vm.isBusy ? 'Working…' : 'Share read-only'),
        ),
      ],
    );
  }

  String _describe(ShareError error) => switch (error) {
    ShareError.notLoggedIn => 'You are logged out. Log in and try again.',
    ShareError.unreachable => 'Your pod could not be reached. Nothing changed.',
    ShareError.failed => 'Your pod refused the change.',
  };

  String _describeProblem(WebIdProblem problem) => switch (problem) {
    WebIdProblem.empty => 'Enter their WebID.',
    WebIdProblem.notALink => 'A WebID is a link, like https://…/card#me.',
    WebIdProblem.yourOwn => 'That is your own WebID.',
  };
}

/// The share just made: the code to tell the recipient, once, in person.
class _CreatedCard extends StatelessWidget {
  const _CreatedCard({required this.share, required this.vm});

  final Share share;
  final ShareViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      key: ShareKeys.created,
      icon: Icons.check_circle_outline_rounded,
      title: 'Shared with ${share.label}',
      tone: CardTone.highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (share.isReport) ...[
            const Text(
              'Their PDF report and CSV are in this folder on your pod. '
              'They open it with their own Solid login, in a Solid data '
              'browser or any Solid app.',
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    key: ShareKeys.createdLink,
                    vm.createdLink?.toString() ?? '',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: ShareKeys.copyLink,
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: vm.createdLink == null
                      ? null
                      : () => _copy(context, vm.createdLink.toString()),
                ),
              ],
            ),
          ] else if (share.code case final code?) ...[
            const Text(
              'Tell them this code in person. It is the only way to read '
              'the share. You can see it again from the list.',
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    key: ShareKeys.createdCode,
                    code,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: ShareKeys.copyCode,
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copy(context, code),
                ),
              ],
            ),
          ] else
            const Text(
              'They can read it as soon as they log in with their WebID.',
            ),
          if (!share.isReport) ...[
            const SizedBox(height: Space.md),
            const Text('Or let them scan this with their phone:'),
            const SizedBox(height: Space.sm),
            QrCodeBox(
              key: ShareKeys.createdQr,
              data: vm.inviteLink(share).toString(),
              label: 'Invite for ${share.label}',
            ),
          ],
          const SizedBox(height: Space.sm),
          TextButton(
            key: ShareKeys.dismissCreated,
            onPressed: vm.dismissCreated,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied')));
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.share,
    required this.vm,
    required this.today,
  });

  final Share share;
  final ShareViewModel vm;
  final DateTime today;

  Future<void> _copyLink(BuildContext context) async {
    final url = await vm.folderUrl(share);
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      key: ShareKeys.card(share),
      icon: Icons.person_outline_rounded,
      title: share.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            share.recipientWebId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(shareContentText(share)),
          Text(key: ShareKeys.end(share), shareEndText(share, today: today)),
          if (vm.isRevealed(share)) ...[
            if (share.code case final code?)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: SelectableText(
                  key: ShareKeys.code(share),
                  code,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: QrCodeBox(
                key: ShareKeys.qr(share),
                data: vm.inviteLink(share).toString(),
                label: 'Invite for ${share.label}',
              ),
            ),
          ],
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              if (share.isReport)
                TextButton.icon(
                  key: ShareKeys.link(share),
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link'),
                )
              else
                TextButton.icon(
                  key: ShareKeys.showCode(share),
                  onPressed: () => vm.toggleRevealed(share),
                  icon: Icon(
                    vm.isRevealed(share)
                        ? Icons.visibility_off_rounded
                        : Icons.qr_code_rounded,
                  ),
                  label: Text(
                    vm.isRevealed(share)
                        ? 'Hide'
                        : share.isEncrypted
                        ? 'Show code and QR'
                        : 'Show QR',
                  ),
                ),
              TextButton.icon(
                key: ShareKeys.revoke(share),
                onPressed: vm.isBusy ? null : () => vm.revoke(share),
                icon: const Icon(Icons.person_remove_rounded),
                label: const Text('End share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
