// The shopping list: what Relief suggested and what the user added, saved
// on the pod, ticked off as it is bought.

import 'package:lilith/data/health_repository.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/shop_links.dart';
import 'package:lilith/ui/core/url_opener.dart';
import 'package:lilith/ui/shopping/shopping_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ShoppingKeys {
  static const Key error = Key('shopping.error');
  static const Key dismissError = Key('shopping.dismissError');
  static const Key empty = Key('shopping.empty');
  static const Key newItem = Key('shopping.newItem');
  static const Key add = Key('shopping.add');
  static const Key problem = Key('shopping.problem');
  static Key item(String name) => Key('shopping.item.$name');
  static Key toggle(String name) => Key('shopping.toggle.$name');
  static Key remove(String name) => Key('shopping.remove.$name');
  static Key nearby(String name) => Key('shopping.nearby.$name');
  static Key online(String name) => Key('shopping.online.$name');
}

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ShoppingViewModel(context.read<HealthRepository>()),
    child: const _ShoppingView(),
  );
}

class _ShoppingView extends StatefulWidget {
  const _ShoppingView();

  @override
  State<_ShoppingView> createState() => _ShoppingViewState();
}

class _ShoppingViewState extends State<_ShoppingView> {
  final _newItem = TextEditingController();
  bool _refused = false;

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  Future<void> _add(ShoppingViewModel vm) async {
    final added = await vm.add(_newItem.text);
    if (!mounted) return;
    setState(() => _refused = !added);
    if (added) _newItem.clear();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ShoppingViewModel>();
    final openUrl = context.read<UrlOpener>();
    return PageScaffold(
      title: 'Shopping list',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: ShoppingKeys.error,
            message: _describe(error),
            dismissKey: ShoppingKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        const Text(
          'Saved privately on your pod. Tick things off as you get them.',
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: ShoppingKeys.newItem,
                controller: _newItem,
                decoration: const InputDecoration(
                  labelText: 'Add your own item',
                  hintText: 'e.g. Heat pad',
                ),
                onSubmitted: (_) => _add(vm),
              ),
            ),
            const SizedBox(width: Space.sm),
            FilledButton.tonal(
              key: ShoppingKeys.add,
              onPressed: () => _add(vm),
              child: const Text('Add'),
            ),
          ],
        ),
        if (_refused)
          const ProblemText(
            key: ShoppingKeys.problem,
            'Type something that is not already on the list.',
          ),
        const SizedBox(height: Space.lg),
        if (vm.isEmpty)
          const AppCard(
            key: ShoppingKeys.empty,
            icon: Icons.shopping_basket_rounded,
            title: 'Nothing on the list',
            child: Text(
              'Relief suggestions with something to buy can be added from '
              'there, or add your own above.',
            ),
          )
        else
          for (final item in vm.items)
            AppCard(
              key: ShoppingKeys.item(item.name),
              child: Column(
                children: [
                  CheckboxListTile(
                    key: ShoppingKeys.toggle(item.name),
                    value: item.bought,
                    onChanged: (_) => vm.toggle(item.name),
                    contentPadding: EdgeInsets.zero,
                    title: StrikeableText(item.name, struck: item.bought),
                    subtitle: item.note == null ? null : Text(item.note!),
                    secondary: IconButton(
                      key: ShoppingKeys.remove(item.name),
                      tooltip: 'Remove ${item.name}',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => vm.remove(item.name),
                    ),
                  ),
                  if (!item.bought)
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        TextButton.icon(
                          key: ShoppingKeys.nearby(item.name),
                          onPressed: () => openUrl(mapsNearMe(item.name)),
                          icon: const Icon(Icons.place_rounded),
                          label: const Text('Find nearby'),
                        ),
                        TextButton.icon(
                          key: ShoppingKeys.online(item.name),
                          onPressed: () => openUrl(retailerSearch(item.name)),
                          icon: const Icon(Icons.shopping_bag_rounded),
                          label: const Text('Buy online'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
      ],
    );
  }

  String _describe(RepositoryError error) => switch (error) {
    RepositoryError.saveFailed =>
      'Your change is kept here but could not be saved to your pod.',
    RepositoryError.notLoggedIn => 'Your session has ended. Log in again.',
    _ => 'Your data could not be read from your pod.',
  };
}
