import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
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
/// with the app's theme. [expectAccessible] switches the theme and text
/// scale of the same tree, so a screen test needs no variants of its own.
Widget harness({
  required SessionRepository session,
  required Widget child,
  HealthRepository? health,
  SetupRepository? setup,
  ShareRepository? shares,
  ReceivedShareRepository? received,
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
    if (received != null) ChangeNotifierProvider.value(value: received),
    ChangeNotifierProvider.value(value: tabs ?? ShellTabs()),
    Provider<UrlOpener>.value(value: openUrl ?? (_) async {}),
    Provider<FileSharer>.value(value: shareFile ?? (_) async {}),
    Provider<PdfReport>.value(value: const PdfReport()),
  ],
  child: HarnessShell(brightness: brightness, child: child),
);

/// The MaterialApp around a screen under test, whose theme and text scale
/// can be switched after the first build.
class HarnessShell extends StatefulWidget {
  const HarnessShell({
    required this.child,
    this.brightness = Brightness.light,
    super.key,
  });

  final Widget child;
  final Brightness brightness;

  @override
  State<HarnessShell> createState() => HarnessShellState();
}

class HarnessShellState extends State<HarnessShell> {
  late Brightness _brightness = widget.brightness;
  double _textScale = 1;

  void set({Brightness? brightness, double? textScale}) => setState(() {
    _brightness = brightness ?? _brightness;
    _textScale = textScale ?? _textScale;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: lilithTheme(_brightness),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(_textScale)),
      child: app!,
    ),
    home: widget.child,
  );
}

/// Flutter's accessibility guidelines: readable text, 48dp targets, labels.
/// Checked as pumped, then in the other theme, then at twice the text size
/// (where an overflow fails the test), and put back. With [variants] false
/// only the tree as pumped is checked.
Future<void> expectAccessible(
  WidgetTester tester, {
  bool variants = true,
}) async {
  await _guidelines(tester);
  if (!variants) return;
  final shell = find.byType(HarnessShell);
  if (shell.evaluate().isEmpty) return;
  final state = tester.state<HarnessShellState>(shell);
  final was = state._brightness;
  final other = was == Brightness.light ? Brightness.dark : Brightness.light;
  state.set(brightness: other);
  await _settle(tester);
  await _guidelines(tester);
  state.set(brightness: was, textScale: 2);
  await _settle(tester);
  await _guidelines(tester);
  state.set(textScale: 1);
  await _settle(tester);
}

/// Lets the theme and colour animations finish. Not pumpAndSettle: a page
/// with a BusyIndicator never settles.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}
