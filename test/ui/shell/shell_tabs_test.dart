import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';

void main() {
  backHistoryTests();
  modeTests();
}

void modeTests() {
  const tracker = [
    ShellTab.today,
    ShellTab.log,
    ShellTab.history,
    ShellTab.relief,
    ShellTab.pod,
  ];
  const partner = [ShellTab.today, ShellTab.learn, ShellTab.pod];

  test('a tracker, and someone who does both, get the tracker tabs', () {
    expect(shellTabsFor(AppMode.tracker), tracker);
    expect(shellTabsFor(AppMode.both), tracker);
  });

  test('a partner gets Today, Learn and Pod', () {
    expect(shellTabsFor(AppMode.partner), partner);
  });

  test('the tracker tabs are allowed until told otherwise', () {
    expect(ShellTabs().allowed, tracker);
  });

  test('allowing fewer tabs leaves a hidden one for Today, and tells', () {
    final tabs = ShellTabs()..show(ShellTab.history);
    var told = 0;
    tabs
      ..addListener(() => told++)
      ..allow(partner);
    expect(tabs.allowed, partner);
    expect(tabs.current, ShellTab.today);
    expect(tabs.canGoBack, isFalse);
    expect(told, 1);
  });

  test('allowing fewer tabs keeps a tab that is still shown', () {
    final tabs = ShellTabs()
      ..show(ShellTab.log)
      ..show(ShellTab.pod)
      ..allow(partner);
    expect(tabs.current, ShellTab.pod);
    expect(tabs.goBack(), isTrue);
    expect(tabs.current, ShellTab.today);
    expect(tabs.canGoBack, isFalse);
  });

  test('allowing the same tabs again tells nobody', () {
    final tabs = ShellTabs();
    var told = 0;
    tabs
      ..addListener(() => told++)
      ..allow(tracker);
    expect(told, 0);
  });

  test('a tab that is not allowed cannot be shown', () {
    final tabs = ShellTabs()..allow(partner);
    tabs.show(ShellTab.history);
    expect(tabs.current, ShellTab.today);
    tabs.openLog(DateTime(2026, 6));
    expect(tabs.current, ShellTab.today);
    expect(tabs.canGoBack, isFalse);
    tabs.show(ShellTab.learn);
    expect(tabs.current, ShellTab.learn);
  });

  test('Learn cannot be shown to a tracker', () {
    final tabs = ShellTabs()..show(ShellTab.learn);
    expect(tabs.current, ShellTab.today);
  });

  test('reset allows the tracker tabs again', () {
    final tabs = ShellTabs()
      ..allow(partner)
      ..reset();
    expect(tabs.allowed, tracker);
  });
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
