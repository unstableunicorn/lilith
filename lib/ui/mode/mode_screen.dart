// The first question a new person is asked, once the pod is set up: how
// they will use Lilith. Settings changes the answer later.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/app_mode.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/mode/mode_chooser.dart';
import 'package:lilith/ui/mode/mode_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ModeKeys {
  static const Key screen = Key('mode.screen');
  static Key option(AppMode m) => Key('mode.option.${m.name}');
  static const Key confirm = Key('mode.confirm');
}

class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ModeViewModel(
      context.read<HealthRepository>(),
      context.read<ReceivedShareRepository>(),
    ),
    child: const _ModeView(),
  );
}

class _ModeView extends StatelessWidget {
  const _ModeView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ModeViewModel>();
    return PageScaffold(
      key: ModeKeys.screen,
      title: 'Welcome to Lilith',
      children: [
        AppCard(
          icon: Icons.people_outline_rounded,
          title: 'How will you use Lilith?',
          tone: CardTone.highlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModeChooser(
                mode: vm.choice,
                keyFor: ModeKeys.option,
                onChanged: vm.choose,
              ),
              const SizedBox(height: Space.sm),
              const Text('You can change this in Settings at any time.'),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        FilledButton(
          key: ModeKeys.confirm,
          onPressed: vm.isBusy ? null : vm.confirm,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Shows [child] once the person has said how they use Lilith, and the
/// question until then. Someone with cycle data already is never asked.
class ModeGate extends StatelessWidget {
  const ModeGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ask = context.select<HealthRepository, bool>(
      (health) => health.isLoaded && health.data.needsMode,
    );
    return ask ? const ModeScreen() : child;
  }
}
