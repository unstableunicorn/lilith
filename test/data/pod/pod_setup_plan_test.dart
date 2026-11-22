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

  test(
    'the key is readable and the log appendable by logged-in users only',
    () {
      expect(
        plan.acls.map((a) => a.resourcePath),
        unorderedEquals([
          'lilith/sharing/public-key.ttl',
          'lilith/logs/permissions-log.ttl',
        ]),
      );
      final byPath = {for (final a in plan.acls) a.resourcePath: a};
      expect(byPath['lilith/sharing/public-key.ttl']!.modes, {AclMode.read});
      expect(byPath['lilith/sharing/public-key.ttl']!.isFile, isTrue);
      expect(byPath['lilith/logs/permissions-log.ttl']!.modes, {
        AclMode.append,
      });
      expect(byPath['lilith/logs/permissions-log.ttl']!.isFile, isTrue);
    },
  );

  test(
    'shared and notifications get no rule at all, so they stay owner-only',
    () {
      expect(plan.filesForInitPod, isNot(contains('lilith/shared/.acl')));
      expect(
        plan.filesForInitPod,
        isNot(contains('lilith/notifications/.acl')),
      );
      expect(
        plan.acls.map((a) => a.resourcePath),
        isNot(contains('lilith/shared')),
      );
      expect(
        plan.acls.map((a) => a.resourcePath),
        isNot(contains('lilith/notifications')),
      );
    },
  );

  test('no file is both left to solidpod and written by the app', () {
    final ours = plan.acls.map((a) => '${a.resourcePath}.acl');
    expect(plan.filesForInitPod.toSet().intersection(ours.toSet()), isEmpty);
  });
}
