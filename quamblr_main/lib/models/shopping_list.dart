class ShoppingItem {
  String name;
  int quantity;
  bool purchased;

  ShoppingItem({
    required this.name,
    required this.quantity,
    this.purchased = false,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      purchased: json['purchased'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'purchased': purchased,
    };
  }
}

class ShoppingList {
  List<ShoppingItem> items;

  ShoppingList({List<ShoppingItem>? items}) : items = items ?? [];

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      items: (json['items'] as List<dynamic>)
          .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
