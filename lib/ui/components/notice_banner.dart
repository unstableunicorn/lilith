// Something the user must see and dismiss, such as a save that failed.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    required this.onDismiss,
    this.detail,
    this.dismissKey,
    super.key,
  });

  final String message;

  /// Technical detail worth copying into a bug report, shown small.
  final String? detail;
  final VoidCallback onDismiss;
  final Key? dismissKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: scheme.errorContainer,
      contentTextStyle: TextStyle(color: scheme.onErrorContainer),
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.sm,
        Space.sm,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (detail case final d?) ...[
            const SizedBox(height: Space.xs),
            Text(
              d,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: dismissKey,
          onPressed: onDismiss,
          style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
