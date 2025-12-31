class MenuItemModel {
  final int? id;
  final String itemName;
  final double price;
  final String? description;
  final String? category;

  MenuItemModel({
    this.id,
    required this.itemName,
    required this.price,
    this.description,
    this.category,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'],
      itemName: json['item_name'],
      price: (json['price'] as num).toDouble(),
      description: json['description'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_name': itemName,
      'price': price,
      'description': description,
      'category': category,
    };
  }
}

class MenuModel {
  final int id;
  final int barId;
  final List<MenuItemModel> items;

  MenuModel({
    required this.id,
    required this.barId,
    required this.items,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'],
      barId: json['bar_id'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => MenuItemModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bar_id': barId,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
