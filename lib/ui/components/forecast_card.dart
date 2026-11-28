// The week ahead, from past cycles: a sentence, a row of likely symptoms,
// and a labelled row of likely moods.

import 'package:lilith/ui/components/app_card.dart';
import 'package:lilith/ui/components/label_badge.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({
    required this.title,
    required this.summary,
    this.symptoms = const [],
    this.moods = const [],
    this.moodsKey,
    super.key,
  });

  final String title;
  final String summary;

  /// One badge each, e.g. "Cramps 60%".
  final List<String> symptoms;

  /// One badge each, under a "Moods" label; no label when empty.
  final List<String> moods;

  /// Finds the moods label and row.
  final Key? moodsKey;

  @override
  Widget build(BuildContext context) => AppCard(
    icon: Icons.insights_rounded,
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        if (symptoms.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          _Badges(symptoms),
        ],
        if (moods.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Column(
            key: moodsKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Moods', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Space.sm),
              _Badges(moods),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Badges extends StatelessWidget {
  const _Badges(this.texts);

  final List<String> texts;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [for (final t in texts) LabelBadge(text: t)],
  );
}
