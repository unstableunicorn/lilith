// Which parts of solidpod's pod set-up the app leaves to solidpod, and which
// access rules it writes itself so that nothing is ever open to the public.
//
// solidpod's initPod grants anyone (foaf:Agent) read on the public key,
// append on the permissions log and the notifications folder, and read and
// write on the shared folder. The owner's rule is nothing public except the
// profile card, so those four rules are written for logged-in users instead.

enum AclMode { read, write, append }

/// One access rule the app writes: [modes] for any logged-in user on
/// [resourcePath] (relative to the pod root, no trailing slash).
class AuthenticatedAcl {
  const AuthenticatedAcl({
    required this.resourcePath,
    required this.isFile,
    required this.modes,
  });

  final String resourcePath;
  final bool isFile;
  final Set<AclMode> modes;
}

class PodSetupPlan {
  const PodSetupPlan({required this.filesForInitPod, required this.acls});

  /// Built from solidpod's `generateDefaultFiles()` map of folder path to
  /// file names.
  factory PodSetupPlan.from(Map<dynamic, dynamic> defaultFiles) {
    final files = <String>[];
    final acls = <AuthenticatedAcl>[];
    for (final entry in defaultFiles.entries) {
      final dir = entry.key as String;
      for (final name in entry.value as List) {
        final file = name as String;
        if (_keyFiles.contains(file)) continue;
        final path = '$dir/$file';
        if (file == '.acl') {
          final modes = _folderModes[dir.split('/').last];
          if (modes == null) {
            files.add(path);
          } else {
            acls.add(
              AuthenticatedAcl(resourcePath: dir, isFile: false, modes: modes),
            );
          }
        } else if (file.endsWith('.acl')) {
          final resource = file.substring(0, file.length - '.acl'.length);
          final modes = _fileModes[resource];
          if (modes == null) {
            files.add(path);
          } else {
            acls.add(
              AuthenticatedAcl(
                resourcePath: '$dir/$resource',
                isFile: true,
                modes: modes,
              ),
            );
          }
        } else {
          files.add(path);
        }
      }
    }
    return PodSetupPlan(filesForInitPod: files, acls: acls);
  }

  /// Paths (pod-root relative) initPod should create. The key files are
  /// absent because initPod writes them from the security key itself.
  final List<String> filesForInitPod;

  /// The rules the app writes after initPod, for logged-in users.
  final List<AuthenticatedAcl> acls;

  static const _keyFiles = {'enc-keys.ttl', 'ind-keys.ttl', 'public-key.ttl'};

  // What solidpod would grant the public, granted to logged-in users instead.
  static const _fileModes = {
    'public-key.ttl': {AclMode.read},
    'permissions-log.ttl': {AclMode.append},
  };
  static const _folderModes = {
    'shared': {AclMode.read, AclMode.write},
    'notifications': {AclMode.append},
  };
}
