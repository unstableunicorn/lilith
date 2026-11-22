import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_setup_plan.dart';

void main() {
  // The shape solidpod's generateDefaultFiles() returns for app folder "lilith".
  final defaults = <dynamic, dynamic>{
    'lilith/sharing': ['public-key.ttl', 'public-key.ttl.acl'],
    'lilith/logs': ['permissions-log.ttl', 'permissions-log.ttl.acl'],
    'lilith/shared': ['.acl'],
    'lilith/encryption': ['enc-keys.ttl', 'ind-keys.ttl'],
    'lilith/notifications': ['.acl'],
    'lilith/profile': ['.acl'],
  };
  final plan = PodSetupPlan.from(defaults);

  test(
    'solidpod creates the key files itself and the owner-only profile ACL',
    () {
      expect(
        plan.filesForInitPod,
        unorderedEquals([
          'lilith/logs/permissions-log.ttl',
          'lilith/profile/.acl',
        ]),
      );
    },
  );

  test('every rule solidpod would open to anyone is written for logged-in users instead', () {
    expect(
      plan.acls.map((a) => a.resourcePath),
      unorderedEquals([
        'lilith/sharing/public-key.ttl',
        'lilith/logs/permissions-log.ttl',
        'lilith/shared',
        'lilith/notifications',
      ]),
    );
    final byPath = {for (final a in plan.acls) a.resourcePath: a};
    expect(byPath['lilith/sharing/public-key.ttl']!.modes, {AclMode.read});
    expect(byPath['lilith/sharing/public-key.ttl']!.isFile, isTrue);
    expect(byPath['lilith/logs/permissions-log.ttl']!.modes, {AclMode.append});
    expect(byPath['lilith/shared']!.modes, {AclMode.read, AclMode.write});
    expect(byPath['lilith/shared']!.isFile, isFalse);
    expect(byPath['lilith/notifications']!.modes, {AclMode.append});
    expect(byPath['lilith/notifications']!.isFile, isFalse);
  });

  test('no file is both left to solidpod and written by the app', () {
    final ours = plan.acls.map(
      (a) =>
          '${a.resourcePath}${a.isFile ? '' : '/'}.acl'.replaceAll('//', '/'),
    );
    expect(plan.filesForInitPod.toSet().intersection(ours.toSet()), isEmpty);
  });
}
