// The wait spinner, centred with room around it.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class BusyIndicator extends StatelessWidget {
  const BusyIndicator({this.label = 'Please wait', super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Semantics(label: label, child: const CircularProgressIndicator()),
    ),
  );
}
