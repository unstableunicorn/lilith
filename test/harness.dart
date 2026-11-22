import 'package:material_ui/material_ui.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:provider/provider.dart';

/// Records the URLs a screen asked to open.
class RecordingUrlOpener {
  final List<Uri> opened = [];
  Future<void> call(Uri url) async => opened.add(url);
}

/// The providers every screen needs, around [child], inside a MaterialApp.
Widget harness({
  required SessionRepository session,
  required Widget child,
  HealthRepository? health,
  UrlOpener? openUrl,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: session),
    if (health != null) ChangeNotifierProvider.value(value: health),
    Provider<UrlOpener>.value(value: openUrl ?? (_) async {}),
  ],
  child: MaterialApp(home: child),
);
