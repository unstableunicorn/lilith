// Which top-level tab is showing. Screens switch tabs through this, so the
// shell is the only widget that knows how tabs are drawn.

import 'package:flutter/foundation.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:material_ui/material_ui.dart';

enum ShellTab {
  today('Today', Icons.spa_rounded),
  log('Log', Icons.edit_note_rounded),
  history('History', Icons.insights_rounded),
  relief('Relief', Icons.healing_rounded),
  pod('Pod', Icons.cloud_rounded),

  /// A tab only for someone who follows and does not track; a page off
  /// Today for everyone else.
  learn('Learn', Icons.menu_book_rounded);

  ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

const List<ShellTab> _trackerTabs = [
  ShellTab.today,
  ShellTab.log,
  ShellTab.history,
  ShellTab.relief,
  ShellTab.pod,
];

/// The tabs [mode] shows, in the order of the bar. Someone who only follows
/// has nothing to log, so the tracker screens go and Learn takes a tab.
List<ShellTab> shellTabsFor(AppMode mode) => mode.tracksOwnCycle
    ? _trackerTabs
    : const [ShellTab.today, ShellTab.learn, ShellTab.pod];

class ShellTabs extends ChangeNotifier {
  List<ShellTab> _allowed = _trackerTabs;

  /// The tabs that can be shown, in the order of the bar.
  List<ShellTab> get allowed => _allowed;

  /// Shows only [tabs] from now on. A tab that goes is forgotten, and
  /// Today shows in its place.
  void allow(List<ShellTab> tabs) {
    if (listEquals(tabs, _allowed)) return;
    _allowed = List.unmodifiable(tabs);
    _visited.removeWhere((t) => !_allowed.contains(t));
    if (!_allowed.contains(_current)) {
      _current = _visited.isEmpty ? ShellTab.today : _visited.removeLast();
    }
    notifyListeners();
  }

  ShellTab _current = ShellTab.today;
  final List<ShellTab> _visited = [];
  DateTime? _logDate;
  int _logRequest = 0;

  ShellTab get current => _current;

  /// Whether the back button has a tab to return to.
  bool get canGoBack => _visited.isNotEmpty;

  /// Returns to the tab shown before this one; false when there is none,
  /// so the caller lets the back button leave the app instead.
  bool goBack() {
    if (_visited.isEmpty) return false;
    _current = _visited.removeLast();
    notifyListeners();
    return true;
  }

  // A tab is remembered once on the way; going round in circles does not
  // grow the history.
  void _switchTo(ShellTab tab) {
    if (tab == _current) return;
    _visited
      ..remove(tab)
      ..add(_current);
    _current = tab;
  }

  /// The day the Log tab was last asked to open, and a counter that changes
  /// with every request so the same day can be asked for twice.
  DateTime? get logDate => _logDate;
  int get logRequest => _logRequest;

  /// Shows the Log tab on [day].
  void openLog(DateTime day) {
    if (!_allowed.contains(ShellTab.log)) return;
    _logDate = day;
    _logRequest++;
    _switchTo(ShellTab.log);
    notifyListeners();
  }

  void show(ShellTab tab) {
    if (tab == _current || !_allowed.contains(tab)) return;
    _switchTo(tab);
    notifyListeners();
  }

  /// Back to Today with nothing remembered, for the next login.
  void reset() {
    _allowed = _trackerTabs;
    _current = ShellTab.today;
    _visited.clear();
    notifyListeners();
  }
}
