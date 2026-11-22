// Which top-level tab is showing. Screens switch tabs through this, so the
// shell is the only widget that knows how tabs are drawn.

import 'package:material_ui/material_ui.dart';

enum ShellTab {
  today('Today', Icons.spa_rounded),
  log('Log', Icons.edit_note_rounded),
  history('History', Icons.insights_rounded),
  pod('Pod', Icons.cloud_rounded);

  const ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ShellTabs extends ChangeNotifier {
  ShellTab _current = ShellTab.today;
  DateTime? _logDate;
  int _logRequest = 0;

  ShellTab get current => _current;

  /// The day the Log tab was last asked to open, and a counter that changes
  /// with every request so the same day can be asked for twice.
  DateTime? get logDate => _logDate;
  int get logRequest => _logRequest;

  /// Shows the Log tab on [day].
  void openLog(DateTime day) {
    _logDate = day;
    _logRequest++;
    _current = ShellTab.log;
    notifyListeners();
  }

  void show(ShellTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
