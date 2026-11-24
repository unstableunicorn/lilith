// Which top-level tab is showing. Screens switch tabs through this, so the
// shell is the only widget that knows how tabs are drawn.

import 'package:material_ui/material_ui.dart';

enum ShellTab {
  today('Today', Icons.spa_rounded),
  log('Log', Icons.edit_note_rounded),
  history('History', Icons.insights_rounded),
  relief('Relief', Icons.healing_rounded),
  pod('Pod', Icons.cloud_rounded);

  ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ShellTabs extends ChangeNotifier {
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
    _logDate = day;
    _logRequest++;
    _switchTo(ShellTab.log);
    notifyListeners();
  }

  void show(ShellTab tab) {
    if (tab == _current) return;
    _switchTo(tab);
    notifyListeners();
  }

  /// Back to Today with nothing remembered, for the next login.
  void reset() {
    _current = ShellTab.today;
    _visited.clear();
    notifyListeners();
  }
}
