// Learn: ask a question of the knowledge base, and read about the cycle's
// phases and the facts.

import 'package:lilith/content/symptom_advice.dart' show Source;
import 'package:lilith/domain/cycle_phase.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/learn/learn_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class LearnKeys {
  static const Key question = Key('learn.question');
  static const Key ask = Key('learn.ask');
  static const Key answer = Key('learn.answer');
  static const Key noAnswer = Key('learn.noAnswer');
  static Key answerSource(String url) => Key('learn.answerSource.$url');
  static Key phase(CyclePhase p) => Key('learn.phase.${p.name}');
  static Key phaseSource(CyclePhase p) => Key('learn.phaseSource.${p.name}');
  static Key fact(String text) => Key('learn.fact.${text.hashCode}');
  static Key factSource(String text) =>
      Key('learn.factSource.${text.hashCode}');
}

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => LearnViewModel(),
    child: const _LearnView(),
  );
}

class _LearnView extends StatefulWidget {
  const _LearnView();

  @override
  State<_LearnView> createState() => _LearnViewState();
}

class _LearnViewState extends State<_LearnView> {
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LearnViewModel>();
    final openUrl = context.read<UrlOpener>();
    return PageScaffold(
      title: 'Learn',
      children: [
        const Text(
          'A kind, curious place to understand your body. Every answer comes '
          'from a trusted health source.',
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          tone: CardTone.highlight,
          icon: Icons.question_answer_rounded,
          title: 'Ask a question',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: LearnKeys.question,
                  controller: _question,
                  decoration: const InputDecoration(
                    hintText: 'Type your question…',
                  ),
                  onSubmitted: vm.ask,
                ),
              ),
              const SizedBox(width: Space.sm),
              FilledButton(
                key: LearnKeys.ask,
                onPressed: () => vm.ask(_question.text),
                child: const Text('Ask'),
              ),
            ],
          ),
        ),
        if (vm.asked)
          switch (vm.answer) {
            final entry? => AppCard(
              key: LearnKeys.answer,
              icon: Icons.lightbulb_rounded,
              title: entry.question,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.answer),
                  const SizedBox(height: Space.md),
                  _Sources(
                    sources: entry.sources,
                    keyFor: LearnKeys.answerSource,
                    openUrl: openUrl,
                  ),
                ],
              ),
            ),
            null => const AppCard(
              key: LearnKeys.noAnswer,
              tone: CardTone.callout,
              icon: Icons.help_outline_rounded,
              title: 'Nothing on that yet',
              child: Text(
                'Try other words, or ask a doctor, nurse or pharmacist. The '
                'facts below cover the basics.',
              ),
            ),
          },
        const SectionHeading('Phases of your cycle'),
        for (final entry in vm.phases)
          AppCard(
            key: LearnKeys.phase(entry.phase),
            title: entry.title,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.text),
                const SizedBox(height: Space.sm),
                _Sources(
                  sources: [entry.source],
                  keyFor: (_) => LearnKeys.phaseSource(entry.phase),
                  openUrl: openUrl,
                ),
              ],
            ),
          ),
        const SectionHeading('Did you know?'),
        for (final fact in vm.facts)
          AppCard(
            key: LearnKeys.fact(fact.text),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fact.text),
                const SizedBox(height: Space.sm),
                _Sources(
                  sources: [fact.source],
                  keyFor: (_) => LearnKeys.factSource(fact.text),
                  openUrl: openUrl,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({
    required this.sources,
    required this.keyFor,
    required this.openUrl,
  });

  final List<Source> sources;
  final Key Function(String url) keyFor;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.xs,
    children: [
      for (final s in sources)
        ActionChip(
          key: keyFor(s.url),
          avatar: const Icon(Icons.open_in_new_rounded),
          label: Text(s.name),
          onPressed: () => openUrl(Uri.parse(s.url)),
        ),
    ],
  );
}
