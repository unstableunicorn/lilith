// One number with its name, for a row of them at the top of a page.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;

  /// The figure, or an em dash when there is none yet.
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: Space.sm),
              Text(value, style: theme.textTheme.titleLarge),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
