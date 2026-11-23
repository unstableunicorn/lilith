import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:solidpod/solidpod.dart' as solid;

void main() {
  group('toPodException maps solidpod failures', () {
    final cases = <({String name, Object error, Type want})>[
      (
        name: 'no session',
        error: solid.NotLoggedInException('x'),
        want: PodNotLoggedInException,
      ),
      (
        name: 'forbidden',
        error: solid.AccessForbiddenException('x'),
        want: PodAccessException,
      ),
      (
        name: 'access failed',
        error: solid.AccessFailedException('x'),
        want: PodAccessException,
      ),
      (
        name: 'cannot decrypt',
        error: solid.ResourceNotDecryptableException('x'),
        want: PodAccessException,
      ),
      (
        name: 'no network',
        error: const SocketException('x'),
        want: PodUnavailableException,
      ),
      (
        name: 'http client error',
        error: const HttpException('x'),
        want: PodUnavailableException,
      ),
      (
        name: 'anything else',
        error: StateError('x'),
        want: PodUnavailableException,
      ),
    ];
    for (final c in cases) {
      test(c.name, () => expect(toPodException(c.error).runtimeType, c.want));
    }

    test('keeps the original message', () {
      expect(
        toPodException(solid.AccessForbiddenException('nope')).message,
        contains('nope'),
      );
    });
  });

  test('the service carries its provider', () {
    final s = SolidPodService(provider: _provider);
    expect(s.provider, _provider);
  });
}

final PodProvider _provider = PodProvider.solidCommunityAu;
