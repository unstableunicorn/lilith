// The lock over the whole app: a number pad for the PIN, and the
// fingerprint or face when it is turned on. A pad, not a text field: the
// lock sits above the app's navigator, where a text field has no overlay
// for its handles.

import 'dart:async';

import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class LockKeys {
  static const Key screen = Key('lock.screen');
  static Key digit(int d) => Key('lock.digit.$d');
  static const Key delete = Key('lock.delete');
  static const Key unlock = Key('lock.unlock');
  static const Key error = Key('lock.error');
  static const Key wait = Key('lock.wait');
  static const Key biometrics = Key('lock.biometrics');
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  bool _wrong = false;
  bool _busy = false;
  Timer? _waitEnds;

  AppLockRepository get _repo => context.read<AppLockRepository>();

  @override
  void initState() {
    super.initState();
    // Offer the fingerprint straight away, as phones do.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _repo.lock.biometrics) {
        unawaited(_repo.unlockWithBiometrics());
      }
    });
  }

  @override
  void dispose() {
    _waitEnds?.cancel();
    super.dispose();
  }

  void _type(int d) {
    if (_entered.length >= 8) return;
    setState(() {
      _entered += '$d';
      _wrong = false;
    });
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final ok = await _repo.tryPin(_entered);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _entered = '';
      _wrong = !ok;
    });
    _followWait();
  }

  /// Rebuilds when a wait ends, so the pad comes back by itself.
  void _followWait() {
    _waitEnds?.cancel();
    final until = _repo.lock.waitUntil;
    if (until == null) return;
    final left = until.difference(_repo.now());
    if (left.isNegative) return;
    _waitEnds = Timer(left, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppLockRepository>();
    final lock = repo.lock;
    final canTry = lock.canTry(repo.now()) && !_busy;
    final theme = Theme.of(context);
    return Scaffold(
      key: LockKeys.screen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: Space.md),
                  Text('Lilith is locked', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Space.sm),
                  Semantics(
                    liveRegion: true,
                    label: _entered.isEmpty
                        ? 'No digits entered'
                        : '${_entered.length} digits entered',
                    child: ExcludeSemantics(
                      child: Text(
                        _entered.isEmpty
                            ? 'Enter your PIN'
                            : '•' * _entered.length,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  if (!lock.canTry(repo.now()))
                    ProblemText(
                      key: LockKeys.wait,
                      'Too many wrong tries. Try again at '
                      '${_clock(lock.waitUntil!)}.',
                    )
                  else if (_wrong)
                    ProblemText(key: LockKeys.error, _warning(lock.failures)),
                  const SizedBox(height: Space.md),
                  _Pad(enabled: canTry, onDigit: _type, onDelete: _delete),
                  const SizedBox(height: Space.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: LockKeys.unlock,
                      onPressed: canTry && _entered.length >= 4
                          ? _unlock
                          : null,
                      child: const Text('Unlock'),
                    ),
                  ),
                  if (lock.biometrics) ...[
                    const SizedBox(height: Space.sm),
                    TextButton.icon(
                      key: LockKeys.biometrics,
                      onPressed: repo.unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Use your fingerprint or face'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _warning(int failures) {
    final left = triesBeforeSignOut - failures;
    return left <= triesBeforeSignOut - triesBeforeWait
        ? 'That PIN is not right. $left more wrong tries and Lilith signs '
              'out of your pod on this phone.'
        : 'That PIN is not right.';
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
  });

  final bool enabled;
  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget key(int d) => _PadButton(
      key: LockKeys.digit(d),
      label: '$d',
      onPressed: enabled ? () => onDigit(d) : null,
      child: Text('$d', style: Theme.of(context).textTheme.headlineSmall),
    );
    return Column(
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72, height: 72),
            key(0),
            _PadButton(
              key: LockKeys.delete,
              label: 'Delete a digit',
              onPressed: enabled ? onDelete : null,
              child: const Icon(Icons.backspace_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.xs),
    child: SizedBox(
      width: 64,
      height: 64,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(shape: const CircleBorder()),
          child: child,
        ),
      ),
    ),
  );
}
