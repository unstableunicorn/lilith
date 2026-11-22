// A small pill naming a quality of the thing beside it, such as how well a
// remedy is backed.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class LabelBadge extends StatelessWidget {
  const LabelBadge({required this.text, this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm + 2,
        vertical: Space.xs,
      ),
      decoration: ShapeDecoration(
        color: scheme.secondaryContainer,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Space.lg, color: scheme.onSecondaryContainer),
            const SizedBox(width: Space.xs),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
