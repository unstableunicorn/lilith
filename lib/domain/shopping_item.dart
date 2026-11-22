// Something to buy for symptom relief, identified by its name.

/// One item on the relief shopping list.
class ShoppingItem {
  const ShoppingItem({
    required this.name,
    this.note,
    this.symptomKey,
    this.bought = false,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    name: json['name'] as String,
    note: json['note'] as String?,
    symptomKey: json['symptom'] as String?,
    bought: json['bought'] as bool? ?? false,
  );

  /// The thing to buy; also the item's identity.
  final String name;

  /// Where the suggestion came from, if anywhere.
  final String? note;

  /// The [Symptom.name] it was added for, if any.
  final String? symptomKey;

  final bool bought;

  ShoppingItem copyWith({bool? bought}) => ShoppingItem(
    name: name,
    note: note,
    symptomKey: symptomKey,
    bought: bought ?? this.bought,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (note != null) 'note': note,
    if (symptomKey != null) 'symptom': symptomKey,
    'bought': bought,
  };

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.name == name &&
      other.note == note &&
      other.symptomKey == symptomKey &&
      other.bought == bought;

  @override
  int get hashCode => Object.hash(name, note, symptomKey, bought);
}
