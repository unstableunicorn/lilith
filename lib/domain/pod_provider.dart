// Where a user's Solid pod lives: a built-in provider or any server they name.

import 'package:meta/meta.dart';

/// A Solid pod provider: the server the app logs in against and the website
/// where the user manages their data.
@immutable
class PodProvider {
  factory PodProvider.fromJson(Map<String, dynamic> json) =>
      custom(json['server'] as String)!;

  const PodProvider._({
    required this.name,
    required this.serverUrl,
    required this.manageUrl,
    required this.isBuiltIn,
    this.allowsSignup = true,
  });

  /// The provider the original app used.
  static final PodProvider solidCommunityAu = PodProvider._(
    name: 'Solid Community AU',
    serverUrl: Uri.https('pods.solidcommunity.au'),
    manageUrl: Uri.https('pods.solidcommunity.au'),
    isBuiltIn: true,
  );

  /// The owner's pod on the home cluster (Community Solid Server). Accounts
  /// are created by its admin, so the app offers login only.
  static final PodProvider unstableUnicorn = PodProvider._(
    name: 'Unstable Unicorn Solid',
    serverUrl: Uri.https('solid.unstableunicorn.dev'),
    manageUrl: Uri.https('solid.unstableunicorn.dev', '/.account/'),
    isBuiltIn: true,
    allowsSignup: false,
  );

  /// Providers offered by name. Any other server goes through [custom].
  static final List<PodProvider> builtIn = List.unmodifiable([
    solidCommunityAu,
    unstableUnicorn,
  ]);

  /// A provider from a server the user typed, or null when it is not a URL.
  /// A bare host is taken as https; a trailing slash is dropped. A server
  /// that matches a built-in provider gives that provider.
  static PodProvider? custom(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        !_hostname.hasMatch(uri.host) ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    final server = uri.replace(
      path: uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path,
    );
    for (final p in builtIn) {
      if (p.serverUrl == server) return p;
    }
    return PodProvider._(
      name: server.host,
      serverUrl: server,
      manageUrl: server,
      isBuiltIn: false,
    );
  }

  static final _hostname = RegExp(r'^[A-Za-z0-9.-]+$');

  final String name;
  final Uri serverUrl;

  /// The provider's own website for managing the pod.
  final Uri manageUrl;
  final bool isBuiltIn;

  /// Whether the provider lets a new user create a pod from the app.
  final bool allowsSignup;

  Map<String, dynamic> toJson() => {'server': serverUrl.toString()};

  @override
  bool operator ==(Object other) =>
      other is PodProvider && other.serverUrl == serverUrl;

  @override
  int get hashCode => serverUrl.hashCode;
}
