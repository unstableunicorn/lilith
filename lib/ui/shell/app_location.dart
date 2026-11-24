// Where the signed-in app is, as a web address: the tab, and how many pages
// are open over it. Each one is a browser history entry.

import 'package:flutter/foundation.dart';
import 'package:lilith/ui/shell/shell_tabs.dart';

@immutable
class AppLocation {
  const AppLocation(this.tab, {this.pages = 0});

  /// `/<tab>` or `/<tab>/<pages>`; anything else is Today with no pages.
  factory AppLocation.fromUri(Uri uri) {
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final tab = ShellTab.values.where(
      (t) => parts.isNotEmpty && t.name == parts.first,
    );
    if (tab.isEmpty) return const AppLocation(ShellTab.today);
    final pages = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return AppLocation(tab.first, pages: pages < 0 ? 0 : pages);
  }

  final ShellTab tab;

  /// Pages pushed over the tabs, dialogs included.
  final int pages;

  Uri get uri => Uri(path: pages == 0 ? '/${tab.name}' : '/${tab.name}/$pages');

  @override
  bool operator ==(Object other) =>
      other is AppLocation && other.tab == tab && other.pages == pages;

  @override
  int get hashCode => Object.hash(tab, pages);

  @override
  String toString() => uri.toString();
}
