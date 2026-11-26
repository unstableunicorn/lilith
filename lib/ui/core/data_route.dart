// A page opened over the tabs. Routes sit beside home in the navigator,
// not inside it, so they cannot see the data home provides; this hands
// the health data on to the page. A page it is opened from passes it on
// again the same way.

import 'package:lilith/data/health_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Opens [page] with the health data of [context], when there is any.
Future<void> pushWithData(BuildContext context, Widget page) {
  final health = context.read<HealthRepository?>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => health == null
          ? page
          : ChangeNotifierProvider.value(value: health, child: page),
    ),
  );
}
