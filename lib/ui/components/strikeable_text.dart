// Text that can be struck through, for a thing that is done.

import 'package:material_ui/material_ui.dart';

class StrikeableText extends StatelessWidget {
  const StrikeableText(this.text, {required this.struck, super.key});

  final String text;
  final bool struck;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: struck
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null,
  );
}
