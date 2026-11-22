// Which parts of solidpod's pod set-up the app leaves to solidpod. The
// owner's rule is that nothing in the pod is open to anyone but the owner,
// except the profile card. solidpod's initPod would open four things to the
// public, so those four are left out: with no rule of their own they keep
// the owner-only rule of their folder. Sharing, when built, opens exactly
// what a share needs, to the named person, for as long as it lasts.

class PodSetupPlan {
  const PodSetupPlan({required this.filesForInitPod});

  /// Built from solidpod's `generateDefaultFiles()` map of folder path to
  /// file names.
  factory PodSetupPlan.from(Map<dynamic, dynamic> defaultFiles) {
    final files = <String>[];
    for (final entry in defaultFiles.entries) {
      final dir = entry.key as String;
      for (final name in entry.value as List) {
        final file = name as String;
        if (_keyFiles.contains(file) || _opensToOthers(dir, file)) continue;
        files.add('$dir/$file');
      }
    }
    return PodSetupPlan(filesForInitPod: files);
  }

  /// Paths (pod-root relative) initPod should create. The key files are
  /// absent because initPod writes them from the security key itself.
  final List<String> filesForInitPod;

  static const _keyFiles = {'enc-keys.ttl', 'ind-keys.ttl', 'public-key.ttl'};

  // The rules solidpod would write for others: a folder's own .acl in the
  // two mailbox folders, and a file's .acl on the key and the log.
  static const _openFolders = {'shared', 'notifications'};
  static const _openFileAcls = {
    'public-key.ttl.acl',
    'permissions-log.ttl.acl',
  };

  static bool _opensToOthers(String dir, String file) =>
      (file == '.acl' && _openFolders.contains(dir.split('/').last)) ||
      _openFileAcls.contains(file);
}
