// The menu in the top-right of every tab: the standard place for what a
// user needs from anywhere, starting with logging out.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/core/app_links.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/reminders/reminders_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

enum AppMenuAction { reminders, androidApp, logout }

abstract final class AppMenuKeys {
  static const Key button = Key('appMenu.button');
  static Key item(AppMenuAction a) => Key('appMenu.${a.name}');
}

class AppMenu extends StatelessWidget {
  const AppMenu({this.offerAndroidApp = kIsWeb, super.key});

  /// Whether to offer the Android download: on the web, not in the app.
  final bool offerAndroidApp;

  @override
  Widget build(BuildContext context) => PopupMenuButton<AppMenuAction>(
    key: AppMenuKeys.button,
    tooltip: 'Menu',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (action) => switch (action) {
      AppMenuAction.reminders => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
      AppMenuAction.androidApp => context.read<UrlOpener>()(
        AppLinks.androidApk,
      ),
      AppMenuAction.logout => context.read<SessionRepository>().logout(),
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        key: AppMenuKeys.item(AppMenuAction.reminders),
        value: AppMenuAction.reminders,
        child: const ListTile(
          leading: Icon(Icons.alarm_rounded),
          title: Text('Reminders'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (offerAndroidApp)
        PopupMenuItem(
          key: AppMenuKeys.item(AppMenuAction.androidApp),
          value: AppMenuAction.androidApp,
          child: const ListTile(
            leading: Icon(Icons.android_rounded),
            title: Text('Get the Android app'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      PopupMenuItem(
        key: AppMenuKeys.item(AppMenuAction.logout),
        value: AppMenuAction.logout,
        child: const ListTile(
          leading: Icon(Icons.logout_rounded),
          title: Text('Log out'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ],
  );
}
