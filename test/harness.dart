import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/ui/core/file_sharer.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Records the URLs a screen asked to open.
class RecordingUrlOpener {
  final List<Uri> opened = [];
  Future<void> call(Uri url) async => opened.add(url);
}

/// The providers every screen needs, around [child], inside a MaterialApp
/// with the app's theme.
Widget harness({
  required SessionRepository session,
  required Widget child,
  HealthRepository? health,
  SetupRepository? setup,
  ShareRepository? shares,
  ShellTabs? tabs,
  UrlOpener? openUrl,
  FileSharer? shareFile,
  Brightness brightness = Brightness.light,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: session),
    if (health != null) ChangeNotifierProvider.value(value: health),
    if (setup != null) ChangeNotifierProvider.value(value: setup),
    if (shares != null) ChangeNotifierProvider.value(value: shares),
    ChangeNotifierProvider.value(value: tabs ?? ShellTabs()),
    Provider<UrlOpener>.value(value: openUrl ?? (_) async {}),
    Provider<FileSharer>.value(value: shareFile ?? (_) async {}),
    Provider<PdfReport>.value(value: const PdfReport()),
  ],
  child: MaterialApp(theme: lilithTheme(brightness), home: child),
);

/// Flutter's accessibility guidelines: readable text, 48dp targets, labels.
Future<void> expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}
