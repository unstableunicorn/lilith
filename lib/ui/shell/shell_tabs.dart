// Which top-level tab is showing. Screens switch tabs through this, so the
// shell is the only widget that knows how tabs are drawn.

import 'package:material_ui/material_ui.dart';

enum ShellTab {
  today('Today', Icons.spa_rounded),
  log('Log', Icons.edit_note_rounded),
  pod('Pod', Icons.cloud_rounded);

  const ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ShellTabs extends ChangeNotifier {
  ShellTab _current = ShellTab.today;

  ShellTab get current => _current;

  void show(ShellTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
