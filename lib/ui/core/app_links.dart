// Where the app's own downloads live.

/// The app's public links, apart from the pod providers'.
abstract final class AppLinks {
  /// The Android app, rebuilt from every push to main by the deploy workflow
  /// and published as the rolling "latest" release.
  static final Uri androidApk = Uri.parse(
    'https://github.com/unstableunicorn/lilith/releases/latest/download/'
    'lilith-android-arm64.apk',
  );
}
