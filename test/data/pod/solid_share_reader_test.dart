import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/solid_share_reader.dart';

void main() {
  const owner =
      'https://solid.unstableunicorn.dev/unstableunicorn/profile/card#me';

  test("the card's storage wins, with a trailing slash", () {
    expect(
      podRootFor(
        owner,
        storage: 'https://solid.unstableunicorn.dev/unstableunicorn/',
      ),
      Uri.parse('https://solid.unstableunicorn.dev/unstableunicorn/'),
    );
    expect(
      podRootFor(owner, storage: 'https://data.example/me'),
      Uri.parse('https://data.example/me/'),
    );
  });

  test('without storage the pod is the folder above profile/card', () {
    expect(
      podRootFor(owner),
      Uri.parse('https://solid.unstableunicorn.dev/unstableunicorn/'),
    );
    expect(
      podRootFor('https://me.example/profile/card#me'),
      Uri.parse('https://me.example/'),
    );
    expect(
      podRootFor('https://pods.example/alice/card#me'),
      Uri.parse('https://pods.example/alice/'),
    );
  });
}
