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
    'solidpod creates the key files itself, the log and the profile ACL',
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

  test('nothing that would open the pod to others is created at all', () {
    for (final open in [
      'lilith/sharing/public-key.ttl.acl',
      'lilith/logs/permissions-log.ttl.acl',
      'lilith/shared/.acl',
      'lilith/notifications/.acl',
    ]) {
      expect(plan.filesForInitPod, isNot(contains(open)));
    }
  });
}
