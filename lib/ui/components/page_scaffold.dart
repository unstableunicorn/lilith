// A page: title bar and a scrolling column of content with the page margin.
// With [onRefresh], pulling down from the top fetches again.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    required this.title,
    required this.children,
    this.actions = const [],
    this.onRefresh,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final List<Widget> children;

  /// What a pull down from the top does; none means the page is static.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: Space.page,
      // Pulling must work on a page shorter than the screen too.
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      children: children,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: switch (onRefresh) {
        final refresh? => RefreshIndicator(onRefresh: refresh, child: list),
        null => list,
      },
    );
  }
}
