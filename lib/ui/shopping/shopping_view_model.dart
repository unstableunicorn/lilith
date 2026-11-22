// What the shopping screen decides: the list with bought items last, and
// what may be added to it.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/domain/shopping_item.dart';

class ShoppingViewModel extends ChangeNotifier {
  ShoppingViewModel(this._repo) {
    _repo.addListener(notifyListeners);
  }

  final HealthRepository _repo;

  bool get isLoaded => _repo.isLoaded;
  RepositoryError? get error => _repo.error;

  /// Unbought first, as the data keeps them.
  List<ShoppingItem> get items => _repo.data.shopping;
  bool get isEmpty => items.isEmpty;
  int get toBuy => items.where((i) => !i.bought).length;

  /// Adds [name], trimmed. False, adding nothing, for a blank or an item
  /// already listed in any case.
  Future<bool> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (items.any((i) => i.name.toLowerCase() == lower)) return false;
    await _repo.apply((d) => d.withShoppingItem(ShoppingItem(name: trimmed)));
    return true;
  }

  Future<void> toggle(String name) => _repo.apply((d) => d.toggleBought(name));

  Future<void> remove(String name) =>
      _repo.apply((d) => d.withoutShoppingItem(name));

  void clearError() => _repo.clearError();

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}
