// The account tab: who is logged in, where the data lives and how it is
// protected, with the way out.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/data/setup_repository.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/data_route.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/design/design_screen.dart';
import 'package:lilith/ui/export/export_screen.dart';
import 'package:lilith/ui/profile/profile_screen.dart';
import 'package:lilith/ui/profile/profile_view_model.dart';
import 'package:lilith/ui/received/received_screen.dart';
import 'package:lilith/ui/received/received_view_model.dart';
import 'package:lilith/ui/share/share_screen.dart';
import 'package:lilith/ui/share/share_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class PodKeys {
  static const Key webId = Key('pod.webId');
  static const Key copy = Key('pod.copy');
  static const Key protection = Key('pod.protection');
  static const Key manage = Key('pod.manage');
  static const Key logout = Key('pod.logout');
  static const Key design = Key('pod.design');
  static const Key profile = Key('pod.profile');
  static const Key profileSummary = Key('pod.profileSummary');
  static const Key export = Key('pod.export');
  static const Key sharingSummary = Key('pod.sharingSummary');
  static const Key sharing = Key('pod.sharing');
  static const Key receivedSummary = Key('pod.receivedSummary');
  static const Key received = Key('pod.received');
}

class PodScreen extends StatelessWidget {
  const PodScreen({this.now = DateTime.now, super.key});

  /// The clock, handed on to the export page.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionRepository>();
    final setup = context.watch<SetupRepository>();
    final openUrl = context.read<UrlOpener>();
    final current = session.session;
    if (current == null) {
      return const PageScaffold(title: 'Your pod', children: []);
    }
    return PageScaffold(
      title: 'Your pod',
      actions: const [AppMenu()],
      children: [
        AppCard(
          icon: Icons.person_rounded,
          title: 'Logged in as',
          child: Row(
            children: [
              Expanded(child: Text(key: PodKeys.webId, current.webId)),
              IconButton(
                key: PodKeys.copy,
                tooltip: 'Copy WebID',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () => _copy(context, current.webId),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.cloud_rounded,
          title: current.provider.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(current.provider.serverUrl.host),
              if (setup.state case SetupReady(:final protection))
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(key: PodKeys.protection, _protection(protection)),
                ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.manage,
                onPressed: () => openUrl(current.provider.manageUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Manage your pod and data'),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.favorite_border_rounded,
          title: 'Your health profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: PodKeys.profileSummary,
                profileSummary(context.watch<HealthRepository>().data.profile),
              ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.profile,
                onPressed: () => _openProfile(context),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit your health profile'),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.people_outline_rounded,
          title: 'Sharing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: PodKeys.sharingSummary,
                sharingSummary(context.watch<ShareRepository>().shares),
              ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.sharing,
                onPressed: () => _openSharing(context),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Share read-only with someone'),
              ),
              Text(
                key: PodKeys.receivedSummary,
                receivedSummary(
                  context.watch<ReceivedShareRepository>().received,
                ),
              ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.received,
                onPressed: () => _openReceived(context),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Shared with you'),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.ios_share_rounded,
          title: 'Export your data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A PDF report for your doctor, or a CSV for a spreadsheet.',
              ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                key: PodKeys.export,
                onPressed: () => _openExport(context),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export as PDF or CSV'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.tonalIcon(
          key: PodKeys.logout,
          onPressed: session.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: Space.xl),
          TextButton(
            key: PodKeys.design,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DesignScreen()),
            ),
            child: const Text('Design gallery (debug builds only)'),
          ),
        ],
      ],
    );
  }

  /// The profile is a page of its own, so it gets the repository by hand.
  void _openProfile(BuildContext context) =>
      unawaited(pushWithData(context, const ProfileScreen()));

  void _openSharing(BuildContext context) {
    final health = context.read<HealthRepository>();
    final shares = context.read<ShareRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: health),
            ChangeNotifierProvider.value(value: shares),
          ],
          child: ShareScreen(now: now),
        ),
      ),
    );
  }

  void _openReceived(BuildContext context) {
    final received = context.read<ReceivedShareRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: received,
          child: ReceivedScreen(now: now),
        ),
      ),
    );
  }

  void _openExport(BuildContext context) {
    final repo = context.read<HealthRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: repo,
          child: ExportScreen(now: now),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('WebID copied')));
  }

  String _protection(DataProtection p) => switch (p) {
    DataProtection.encrypted =>
      'Your data is encrypted with your security key. Only you can read it.',
    DataProtection.plain =>
      "Your data is stored readable, protected by your pod's access rules.",
  };
}
