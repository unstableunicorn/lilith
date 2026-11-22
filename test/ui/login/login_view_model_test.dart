import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/session_repository.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:lilith/ui/login/login_view_model.dart';

import '../../fakes/fake_pod_session_service.dart';
import '../../fakes/fake_settings_store.dart';

void main() {
  late FakePodSessionService auth;
  late SessionRepository session;
  late LoginViewModel vm;

  setUp(() {
    auth = FakePodSessionService();
    session = SessionRepository(auth, FakeSettingsStore());
    vm = LoginViewModel(session);
  });

  test('offers the built-in providers plus another one', () {
    expect(vm.builtIn, PodProvider.builtIn);
    expect(vm.selected, PodProvider.builtIn.first);
    expect(vm.isCustom, isFalse);
    expect(vm.canLogin, isTrue);
  });

  test('starts from the provider the session remembers', () async {
    final remembered = SessionRepository(
      auth,
      FakeSettingsStore()..provider = PodProvider.unstableUnicorn,
    );
    await remembered.restore();
    expect(LoginViewModel(remembered).selected, PodProvider.unstableUnicorn);
  });

  test('a remembered custom provider starts in the custom field', () async {
    final custom = PodProvider.custom('https://pods.example.org')!;
    final remembered = SessionRepository(
      auth,
      FakeSettingsStore()..provider = custom,
    );
    await remembered.restore();
    final v = LoginViewModel(remembered);
    expect(v.isCustom, isTrue);
    expect(v.customServer, 'https://pods.example.org');
    expect(v.selected, custom);
  });

  group('choosing another provider', () {
    final cases =
        <({String name, String typed, bool canLogin, LoginError? error})>[
          (
            name: 'nothing typed yet is not an error',
            typed: '',
            canLogin: false,
            error: null,
          ),
          (
            name: 'a valid host',
            typed: 'pods.example.org',
            canLogin: true,
            error: null,
          ),
          (
            name: 'not a URL',
            typed: 'not a url',
            canLogin: false,
            error: LoginError.invalidServer,
          ),
        ];
    for (final c in cases) {
      test(c.name, () {
        vm.chooseCustom();
        vm.setCustomServer(c.typed);
        expect(vm.isCustom, isTrue);
        expect(vm.canLogin, c.canLogin);
        expect(vm.error, c.error);
      });
    }

    test('typing a built-in server selects that provider', () {
      vm.chooseCustom();
      vm.setCustomServer('solid.unstableunicorn.dev');
      expect(vm.selected, PodProvider.unstableUnicorn);
    });

    test('choosing a built-in provider again leaves custom mode', () {
      vm.chooseCustom();
      vm.setCustomServer('pods.example.org');
      vm.choose(PodProvider.solidCommunityAu);
      expect(vm.isCustom, isFalse);
      expect(vm.selected, PodProvider.solidCommunityAu);
    });
  });

  test('warms the login up for whichever provider is selected', () async {
    await Future<void>.delayed(Duration.zero);
    expect(auth.prepared, [PodProvider.builtIn.first]);
    vm.choose(PodProvider.unstableUnicorn);
    vm.chooseCustom();
    vm.setCustomServer('not a url');
    vm.setCustomServer('pods.example.org');
    await Future<void>.delayed(Duration.zero);
    expect(auth.prepared, [
      PodProvider.builtIn.first,
      PodProvider.unstableUnicorn,
      PodProvider.custom('pods.example.org'),
    ]);
  });

  test('the manage-your-data link follows the selected provider', () {
    expect(vm.manageUrl, PodProvider.builtIn.first.manageUrl);
    vm.choose(PodProvider.unstableUnicorn);
    expect(vm.manageUrl, PodProvider.unstableUnicorn.manageUrl);
    vm.chooseCustom();
    expect(vm.manageUrl, isNull);
  });

  group('login', () {
    testWidgets('logs in at the selected provider', (tester) async {
      await tester.pumpWidget(const SizedBox());
      vm.choose(PodProvider.unstableUnicorn);
      await vm.login(tester.element(find.byType(SizedBox)));
      expect(session.session?.provider, PodProvider.unstableUnicorn);
      expect(vm.error, isNull);
      expect(vm.isBusy, isFalse);
    });

    testWidgets('stays busy once the page has left for the provider', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      auth.redirects = true;
      await vm.login(tester.element(find.byType(SizedBox)));
      expect(vm.isBusy, isTrue);
      expect(vm.error, isNull);
    });

    testWidgets('is busy while the browser is open', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final busy = <bool>[];
      vm.addListener(() => busy.add(vm.isBusy));
      await vm.login(tester.element(find.byType(SizedBox)));
      expect(busy.first, isTrue);
      expect(busy.last, isFalse);
    });

    final failures = <({String name, PodException thrown, LoginError want})>[
      (
        name: 'the user gave up',
        thrown: const PodLoginCancelledException(),
        want: LoginError.cancelled,
      ),
      (
        name: 'the provider refused',
        thrown: const PodLoginFailedException('x'),
        want: LoginError.failed,
      ),
      (
        name: 'the provider is unreachable',
        thrown: const PodUnavailableException('x'),
        want: LoginError.unreachable,
      ),
    ];
    for (final f in failures) {
      testWidgets(f.name, (tester) async {
        await tester.pumpWidget(const SizedBox());
        auth.failLogin = f.thrown;
        await vm.login(tester.element(find.byType(SizedBox)));
        expect(vm.error, f.want);
        expect(session.session, isNull);
        expect(vm.isBusy, isFalse);
      });
    }

    testWidgets('does nothing when it cannot log in', (tester) async {
      await tester.pumpWidget(const SizedBox());
      vm.chooseCustom();
      await vm.login(tester.element(find.byType(SizedBox)));
      expect(auth.logins, isEmpty);
    });
  });
}
