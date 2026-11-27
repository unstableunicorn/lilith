// The menu in the top-right of every tab: the standard place for what a
// user needs from anywhere, starting with logging out.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/ui/about/about_screen.dart';
import 'package:lilith/ui/core/app_links.dart';
import 'package:lilith/ui/core/data_route.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:lilith/ui/settings/settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

enum AppMenuAction { profile, settings, about, androidApp, logout }

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
      AppMenuAction.profile => pushWithData(context, const ProfileScreen()),
      AppMenuAction.settings => pushWithData(context, const SettingsScreen()),
      AppMenuAction.androidApp => context.read<Downloader>()(
        AppLinks.androidApk,
      ),
      AppMenuAction.about => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
      AppMenuAction.logout => context.read<SessionRepository>().logout(),
    },
    itemBuilder: (context) => [
      // Someone who only follows has no health profile to keep.
      if (context.read<HealthRepository?>()?.data.modeInForce.tracksOwnCycle ??
          true)
        PopupMenuItem(
          key: AppMenuKeys.item(AppMenuAction.profile),
          value: AppMenuAction.profile,
          child: const ListTile(
            leading: Icon(Icons.favorite_border_rounded),
            title: Text('Health profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      PopupMenuItem(
        key: AppMenuKeys.item(AppMenuAction.settings),
        value: AppMenuAction.settings,
        child: const ListTile(
          leading: Icon(Icons.settings_rounded),
          title: Text('Settings'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        key: AppMenuKeys.item(AppMenuAction.about),
        value: AppMenuAction.about,
        child: const ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('About'),
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
