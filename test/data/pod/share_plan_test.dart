import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/domain/share.dart';
import 'package:solidpod/solidpod.dart' show turtleToTripleMap;

void main() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';
  const wife = 'https://solid.unstableunicorn.dev/wife/profile/card#me';
  final plan = SharePlan.forRecipient(wife);

  test('the share lives in its own folder under the data folder', () {
    expect(plan.folderPath, 'shares/${shareId(wife)}');
    expect(plan.documentPath, 'shares/${shareId(wife)}/cycle_data.json');
  });

  test('the recipient fetches the copy under the sharer\'s pod root', () {
    expect(
      plan.documentUrl(Uri.parse('https://solid.unstableunicorn.dev/owner/')),
      Uri.parse(
        'https://solid.unstableunicorn.dev/owner/lilith/data/shares/'
        '${shareId(wife)}/cycle_data.json',
      ),
    );
  });

  group('the folder ACL', () {
    const acl = 'http://www.w3.org/ns/auth/acl#';
    late Map<String, Map<String, dynamic>> rules;

    setUpAll(() async {
      final turtle = await plan.aclTurtle(
        ownerWebId: owner,
        folderUrl:
            'https://solid.unstableunicorn.dev/unstableunicorn/lilith/data/'
            '${plan.folderPath}/',
      );
      expect(turtle, isNot(contains('agentClass')));
      expect(turtle, isNot(contains('origin')));
      rules = turtleToTripleMap(turtle)
          .map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    });

    Set<String> agentsOf(String rule) {
      final agent = rules[rule]!['${acl}agent'];
      return agent is List ? agent.cast<String>().toSet() : {agent as String};
    }

    test('names three rules, one per mode', () {
      expect(rules.keys, unorderedEquals(['#Read', '#Write', '#Control']));
      for (final rule in rules.values) {
        expect(rule['${acl}accessTo'], './');
        expect(rule['${acl}default'], './');
      }
    });

    test('the recipient reads; only the owner writes and controls', () {
      expect(agentsOf('#Read'), {owner, wife});
      expect(agentsOf('#Write'), {owner});
      expect(agentsOf('#Control'), {owner});
    });
  });
}
