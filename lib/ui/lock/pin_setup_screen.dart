// Turning the app lock on (a PIN typed twice) or off (the PIN once). Opened
// from Settings; goes back once done.

import 'package:flutter/services.dart';
import 'package:lilith/data/app_lock_repository.dart';
import 'package:lilith/domain/app_lock.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class PinSetupKeys {
  static const Key current = Key('pinSetup.current');
  static const Key pin = Key('pinSetup.pin');
  static const Key again = Key('pinSetup.again');
  static const Key save = Key('pinSetup.save');
  static const Key error = Key('pinSetup.error');
}

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save(AppLockRepository repo, {required bool turningOff}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    if (turningOff) {
      if (!await repo.turnOff(_current.text)) error = 'That PIN is not right.';
    } else if (!isValidPin(_pin.text)) {
      error = 'A PIN is 4 to 8 digits.';
    } else if (_pin.text != _again.text) {
      error = 'The two PINs are not the same.';
    } else {
      await repo.setPin(_pin.text);
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppLockRepository>();
    final turningOff = repo.lock.isEnabled;
    Widget field(Key key, TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: TextField(
        key: key,
        controller: c,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(8),
        ],
        decoration: InputDecoration(labelText: label),
      ),
    );
    return PageScaffold(
      title: turningOff ? 'Turn off the app lock' : 'Set a PIN',
      children: [
        AppCard(
          icon: Icons.lock_outline_rounded,
          title: turningOff ? 'Your PIN' : 'A PIN for this phone',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                turningOff
                    ? 'Enter your PIN to turn the lock off.'
                    : 'Lilith asks for it each time it starts, and when you '
                          'come back after five minutes away. It is kept on '
                          'this phone only. After 5 wrong tries Lilith makes '
                          'you wait; after 10 it signs out of your pod.',
              ),
              const SizedBox(height: Space.md),
              if (turningOff)
                field(PinSetupKeys.current, _current, 'PIN')
              else ...[
                field(PinSetupKeys.pin, _pin, 'New PIN, 4 to 8 digits'),
                field(PinSetupKeys.again, _again, 'The same PIN again'),
              ],
              if (_error case final e?) ProblemText(key: PinSetupKeys.error, e),
              FilledButton(
                key: PinSetupKeys.save,
                onPressed: _busy
                    ? null
                    : () => _save(repo, turningOff: turningOff),
                child: Text(turningOff ? 'Turn off' : 'Turn on'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
