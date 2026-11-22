// The Relief tab: pick a symptom, read when to see someone, try the remedies
// and say which helped.

import 'package:lilith/content/symptom_advice.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/shop_links.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/relief/relief_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ReliefKeys {
  static const Key error = Key('relief.error');
  static const Key dismissError = Key('relief.dismissError');
  static const Key seeDoctor = Key('relief.seeDoctor');
  static Key symptom(Symptom s) => Key('relief.symptom.${s.name}');
  static Key remedy(String title) => Key('relief.remedy.$title');
  static Key helped(String title) => Key('relief.helped.$title');
  static Key didNotHelp(String title) => Key('relief.didNotHelp.$title');
  static Key addToList(String title) => Key('relief.addToList.$title');
  static Key nearby(String title) => Key('relief.nearby.$title');
  static Key online(String title) => Key('relief.online.$title');
  static Key source(String title, String url) =>
      Key('relief.source.$title.$url');
}

class ReliefScreen extends StatelessWidget {
  const ReliefScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        ReliefViewModel(context.read<HealthRepository>(), now: now),
    child: const _ReliefView(),
  );
}

class _ReliefView extends StatelessWidget {
  const _ReliefView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReliefViewModel>();
    final openUrl = context.read<UrlOpener>();
    return PageScaffold(
      title: 'Relief',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: ReliefKeys.error,
            message: _describe(error),
            dismissKey: ReliefKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        const Text(
          'Gentle, well-sourced ideas for how you feel. Say what works and it '
          'moves to the top.',
        ),
        const SectionHeading('What is bothering you?'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final s in vm.ordered)
              ChoiceChip(
                key: ReliefKeys.symptom(s),
                label: Text(s.label),
                selected: vm.selected == s,
                onSelected: (_) => vm.select(s),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          key: ReliefKeys.seeDoctor,
          tone: CardTone.callout,
          icon: Icons.medical_services_rounded,
          title: 'When to see a professional',
          child: Text(vm.advice.seeDoctorIf),
        ),
        for (final r in vm.remedies)
          _RemedyCard(remedy: r, vm: vm, openUrl: openUrl),
        const AppCard(
          tone: CardTone.callout,
          icon: Icons.info_outline_rounded,
          title: 'This is information, not medical advice',
          child: Text(
            'If something worries you, or a symptom is new, severe or not '
            'settling, talk to a doctor, nurse or pharmacist.',
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

class _RemedyCard extends StatelessWidget {
  const _RemedyCard({
    required this.remedy,
    required this.vm,
    required this.openUrl,
  });

  final Remedy remedy;
  final ReliefViewModel vm;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = vm.ratingFor(remedy);
    final helped = rating == RemedyRating.helped;
    final item = remedy.shopItem;
    return AppCard(
      key: ReliefKeys.remedy(remedy.title),
      tone: helped ? CardTone.highlight : CardTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (helped) ...[
                const Icon(Icons.star_rounded),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Text(remedy.title, style: theme.textTheme.titleMedium),
              ),
              LabelBadge(icon: _tierIcon(remedy.tier), text: remedy.tier.label),
            ],
          ),
          if (rating == RemedyRating.didNotHelp)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                'You marked this as not for you; kept here just in case.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: Space.md),
          Text(remedy.howTo),
          const SizedBox(height: Space.sm),
          Text(remedy.whyItHelps, style: theme.textTheme.bodySmall),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final s in remedy.sources)
                ActionChip(
                  key: ReliefKeys.source(remedy.title, s.url),
                  avatar: const Icon(Icons.open_in_new_rounded),
                  label: Text(s.name),
                  onPressed: () => openUrl(Uri.parse(s.url)),
                ),
            ],
          ),
          const Divider(height: Space.xl),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                key: ReliefKeys.helped(remedy.title),
                onPressed: () => vm.toggleHelped(remedy),
                icon: Icon(
                  helped
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                label: Text(helped ? 'Helped me' : 'This helped'),
              ),
              TextButton.icon(
                key: ReliefKeys.didNotHelp(remedy.title),
                onPressed: () => vm.toggleDidNotHelp(remedy),
                icon: const Icon(Icons.thumb_down_alt_outlined),
                label: const Text("Didn't help"),
              ),
              if (item != null) ...[
                OutlinedButton.icon(
                  key: ReliefKeys.addToList(remedy.title),
                  onPressed: vm.isOnList(remedy)
                      ? null
                      : () => vm.addToList(remedy),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    vm.isOnList(remedy) ? 'On your list' : 'Add to list',
                  ),
                ),
                TextButton.icon(
                  key: ReliefKeys.nearby(remedy.title),
                  onPressed: () => openUrl(mapsNearMe(item)),
                  icon: const Icon(Icons.place_rounded),
                  label: const Text('Find nearby'),
                ),
                TextButton.icon(
                  key: ReliefKeys.online(remedy.title),
                  onPressed: () => openUrl(retailerSearch(item)),
                  icon: const Icon(Icons.shopping_bag_rounded),
                  label: const Text('Buy online'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _tierIcon(EvidenceTier tier) => switch (tier) {
    EvidenceTier.clinical => Icons.verified_rounded,
    EvidenceTier.community => Icons.groups_rounded,
    EvidenceTier.both => Icons.workspace_premium_rounded,
  };
}
