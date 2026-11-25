// Which build of the app this is. The name follows pubspec.yaml (a test
// keeps them equal); the deploy workflow passes the build number and the
// commit with --dart-define, so a local build has neither.

class AppVersion {
  const AppVersion({required this.name, this.build = '', this.commit = ''});

  /// This build.
  static const AppVersion current = AppVersion(
    name: '0.2.1',
    build: String.fromEnvironment('LILITH_BUILD'),
    commit: String.fromEnvironment('LILITH_COMMIT'),
  );

  /// The version name, raised with each change worth testing.
  final String name;

  /// The deploy run that made it, the `#N` in the release's title.
  final String build;

  /// The full commit it was built from.
  final String commit;

  /// Whether it was built outside the deploy workflow.
  bool get isLocal => build.isEmpty || commit.isEmpty;

  /// The commit's short form, as GitHub shows it.
  String get shortCommit => commit.length > 7 ? commit.substring(0, 7) : commit;
}
