class PurchasedItem {
  String name;
  double price;
  int quantity;
  int boughtBy;
  List<int> splitWith;
  List<int> claimedBy;
  List<int> pendingConfirm;

  PurchasedItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.boughtBy,
    List<int>? splitWith,
    List<int>? claimedBy,
    List<int>? pendingConfirm,
  })  : splitWith = splitWith ?? [],
        claimedBy = claimedBy ?? [],
        pendingConfirm = pendingConfirm ?? [];

  factory PurchasedItem.fromJson(Map<String, dynamic> json) {
    return PurchasedItem(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      boughtBy: json['boughtBy'] as int,
      splitWith: (json['splitWith'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      claimedBy: (json['claimedBy'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      pendingConfirm: (json['pendingConfirm'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'boughtBy': boughtBy,
      'splitWith': splitWith,
      'claimedBy': claimedBy,
      'pendingConfirm': pendingConfirm,
    };
  }
}

class ItemList {
  List<PurchasedItem> items;
  double totalCost;
  bool distributed;

  ItemList({
    List<PurchasedItem>? items,
    this.totalCost = 0.00,
    this.distributed = false,
  }) : items = items ?? [];

  factory ItemList.fromJson(Map<String, dynamic> json) {
    return ItemList(
      items: (json['items'] as List<dynamic>)
          .map((e) => PurchasedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.00,
      distributed: json['distributed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'totalCost': totalCost,
      'distributed': distributed,
    };
  }
}
