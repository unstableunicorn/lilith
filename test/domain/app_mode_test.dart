import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';

void main() {
  group('AppMode', () {
    test('a tracker and "both" track their own cycle; a partner does not', () {
      expect(AppMode.tracker.tracksOwnCycle, isTrue);
      expect(AppMode.both.tracksOwnCycle, isTrue);
      expect(AppMode.partner.tracksOwnCycle, isFalse);
    });

    test('a partner and "both" follow someone; a tracker does not', () {
      expect(AppMode.partner.followsSomeone, isTrue);
      expect(AppMode.both.followsSomeone, isTrue);
      expect(AppMode.tracker.followsSomeone, isFalse);
    });

    test('reads its own names and nothing else', () {
      for (final mode in AppMode.values) {
        expect(AppMode.fromName(mode.name), mode);
      }
      expect(AppMode.fromName(null), isNull);
      expect(AppMode.fromName('coach'), isNull);
      expect(AppMode.fromName(3), isNull);
    });
  });

  group('HealthData.mode', () {
    final received = ReceivedShare(
      sharerWebId: 'https://pod.example.org/ada/profile/card#me',
      label: 'Ada',
      addedOn: DateTime(2026, 6),
    );

    test('is unchosen at first, and a tracker is in force', () {
      expect(HealthData.empty.mode, isNull);
      expect(HealthData.empty.modeInForce, AppMode.tracker);
    });

    test('withMode records the choice and keeps everything else', () {
      final data = HealthData.empty.withReceived(received);
      final partner = data.withMode(AppMode.partner);
      expect(partner.mode, AppMode.partner);
      expect(partner.modeInForce, AppMode.partner);
      expect(partner.received, data.received);
      expect(partner, isNot(data));
      expect(partner.hashCode, isNot(data.hashCode));
    });

    test('the mode survives another change', () {
      final data = HealthData.empty
          .withMode(AppMode.both)
          .withPeriod(PeriodEvent(startDate: DateTime(2026, 6)));
      expect(data.mode, AppMode.both);
    });

    test('a new person is asked; shares received do not answer it', () {
      expect(HealthData.empty.needsMode, isTrue);
      expect(HealthData.empty.withReceived(received).needsMode, isTrue);
    });

    test('someone with cycle data, or a choice made, is not asked', () {
      expect(
        HealthData.empty
            .withPeriod(PeriodEvent(startDate: DateTime(2026, 6)))
            .needsMode,
        isFalse,
      );
      expect(HealthData.empty.withMode(AppMode.tracker).needsMode, isFalse);
    });
  });

  group('HealthData.followedShare', () {
    ReceivedShare from(String name) => ReceivedShare(
      sharerWebId: 'https://pod.example.org/$name/profile/card#me',
      label: name,
      addedOn: DateTime(2026, 6),
    );
    final ada = from('ada');
    final bea = from('bea');
    final two = HealthData.empty.withReceived(ada).withReceived(bea);

    test('is nobody when nobody shares', () {
      expect(HealthData.empty.followedShare, isNull);
    });

    test('is the first share until one is chosen', () {
      expect(two.followedShare, ada);
    });

    test('is the one chosen, and the choice is part of the value', () {
      final chosen = two.withFollowed(bea.sharerWebId);
      expect(chosen.followedShare, bea);
      expect(chosen, isNot(two));
      expect(chosen.hashCode, isNot(two.hashCode));
    });

    test('falls back to the first when the chosen share is removed', () {
      final chosen = two
          .withFollowed(bea.sharerWebId)
          .withoutReceived(bea.sharerWebId);
      expect(chosen.followedShare, ada);
    });
  });
}
