// Where a user's Solid pod lives: a built-in provider or any server they name.

/// A Solid pod provider: the server the app logs in against and the website
/// where the user manages their data.
class PodProvider {
  PodProvider._({
    required this.name,
    required this.serverUrl,
    required this.manageUrl,
    required this.isBuiltIn,
  });

  /// The provider the original app used.
  static final PodProvider solidCommunityAu = PodProvider._(
    name: 'Solid Community AU',
    serverUrl: Uri.https('pods.solidcommunity.au'),
    manageUrl: Uri.https('pods.solidcommunity.au'),
    isBuiltIn: true,
  );

  /// Providers offered by name. Any other server goes through [custom].
  static final List<PodProvider> builtIn = List.unmodifiable([
    solidCommunityAu,
  ]);

  /// A provider from a server the user typed, or null when it is not a URL.
  /// A bare host is taken as https; a trailing slash is dropped.
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
    return PodProvider._(
      name: server.host,
      serverUrl: server,
      manageUrl: server,
      isBuiltIn: false,
    );
  }

  /// A built-in provider by server, else a custom one for that server.
  factory PodProvider.fromJson(Map<String, dynamic> json) {
    final server = Uri.parse(json['server'] as String);
    for (final p in builtIn) {
      if (p.serverUrl == server) return p;
    }
    return custom(server.toString())!;
  }

  static final _hostname = RegExp(r'^[A-Za-z0-9.-]+$');

  final String name;
  final Uri serverUrl;

  /// The provider's own website for managing the pod.
  final Uri manageUrl;
  final bool isBuiltIn;

  Map<String, dynamic> toJson() => {'server': serverUrl.toString()};

  @override
  bool operator ==(Object other) =>
      other is PodProvider && other.serverUrl == serverUrl;

  @override
  int get hashCode => serverUrl.hashCode;
}
