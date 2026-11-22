// The card every panel on a page is: optional icon and title, then content.
// Its tone says what kind of panel: plain, a highlight, or a callout to read.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

enum CardTone { plain, highlight, callout }

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.icon,
    this.title,
    this.tone = CardTone.plain,
    super.key,
  });

  final IconData? icon;
  final String? title;
  final CardTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, accent) = switch (tone) {
      CardTone.plain => (null, scheme.onSurface, scheme.primary),
      CardTone.highlight => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.onPrimaryContainer,
      ),
      CardTone.callout => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: accent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon),
                        const SizedBox(width: Space.sm),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
