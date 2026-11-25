// Where the app's own downloads live.

/// The app's public links, apart from the pod providers'.
abstract final class AppLinks {
  /// The Android app, rebuilt from every push to main by the deploy workflow
  /// and published on the release tagged `latest`. Named by tag, not through
  /// GitHub's "latest release" alias, which skips pre-releases.
  static final Uri androidApk = Uri.parse(
    'https://github.com/unstableunicorn/lilith/releases/download/latest/'
    'lilith-android-arm64.apk',
  );

  /// The page of the release tagged `latest`, which names its build number.
  static final Uri latestBuild = Uri.parse(
    'https://github.com/unstableunicorn/lilith/releases/tag/latest',
  );

  /// The app's source code.
  static final Uri source = Uri.parse(
    'https://github.com/unstableunicorn/lilith',
  );
}
