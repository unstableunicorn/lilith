// A short line saying what is wrong with an entry, next to the control.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class ProblemText extends StatelessWidget {
  const ProblemText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
