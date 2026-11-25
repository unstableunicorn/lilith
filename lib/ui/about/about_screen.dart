// About: which version and build this is, so a tester can tell whether
// they have the newest one, and where the source lives.

import 'package:lilith/ui/about/app_version.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/app_links.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class AboutKeys {
  static const Key version = Key('about.version');
  static const Key local = Key('about.local');
  static const Key commit = Key('about.commit');
  static const Key latest = Key('about.latest');
  static const Key source = Key('about.source');
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({this.version = AppVersion.current, super.key});

  final AppVersion version;

  @override
  Widget build(BuildContext context) {
    final open = context.read<UrlOpener>();
    return PageScaffold(
      title: 'About',
      children: [
        AppCard(
          icon: Icons.info_outline_rounded,
          title: 'This version',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: AboutKeys.version,
                version.isLocal
                    ? 'Version ${version.name}'
                    : 'Version ${version.name}, build ${version.build}',
              ),
              if (version.isLocal)
                const Text(
                  key: AboutKeys.local,
                  'Built on a computer, not by the deploy, so it has no '
                  'build number.',
                )
              else
                ListTile(
                  key: AboutKeys.commit,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Built from ${version.shortCommit}'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => open(
                    Uri.parse(
                      'https://github.com/unstableunicorn/lilith/commit/'
                      '${version.commit}',
                    ),
                  ),
                ),
              ListTile(
                key: AboutKeys.latest,
                contentPadding: EdgeInsets.zero,
                title: const Text('See the newest build'),
                subtitle: const Text(
                  'Its build number is in the title. If it is higher than '
                  'yours, download it again.',
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => open(AppLinks.latestBuild),
              ),
            ],
          ),
        ),
        AppCard(
          icon: Icons.code_rounded,
          title: 'Source',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lilith is free software under the GNU AGPL, version 3 or '
                'later, rewritten from CybrKat’s original LillithApp.',
              ),
              ListTile(
                key: AboutKeys.source,
                contentPadding: EdgeInsets.zero,
                title: const Text('The source code'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => open(AppLinks.source),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
