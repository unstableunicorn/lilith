import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';

void main() {
  backHistoryTests();
}

void backHistoryTests() {
  test('back retraces the tabs visited, once each, then has nothing', () {
    final tabs = ShellTabs();
    expect(tabs.canGoBack, isFalse);
    expect(tabs.goBack(), isFalse);
    tabs.show(ShellTab.log);
    tabs.show(ShellTab.history);
    tabs.show(ShellTab.log);
    expect(tabs.current, ShellTab.log);
    expect(tabs.goBack(), isTrue);
    expect(tabs.current, ShellTab.history);
    expect(tabs.goBack(), isTrue);
    expect(tabs.current, ShellTab.today);
    expect(tabs.canGoBack, isFalse);
  });

  test('opening Log from another tab is remembered too', () {
    final tabs = ShellTabs()..show(ShellTab.history);
    tabs.openLog(DateTime(2026, 6, 1));
    expect(tabs.current, ShellTab.log);
    expect(tabs.goBack(), isTrue);
    expect(tabs.current, ShellTab.history);
  });

  test('reset starts again on Today with nothing to go back to', () {
    final tabs = ShellTabs()
      ..show(ShellTab.history)
      ..show(ShellTab.pod);
    var told = 0;
    tabs
      ..addListener(() => told++)
      ..reset();
    expect(tabs.current, ShellTab.today);
    expect(tabs.canGoBack, isFalse);
    expect(told, 1);
  });
}
