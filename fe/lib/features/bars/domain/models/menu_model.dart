class MenuItemModel {
  final int? id;
  final int? menuId;
  final String itemName;
  final double price;
  final String? description;
  final String? category;
  final bool available;
  final String? picture;
  final int displayOrder;

  MenuItemModel({
    this.id,
    this.menuId,
    required this.itemName,
    required this.price,
    this.description,
    this.category,
    this.available = true,
    this.picture,
    this.displayOrder = 0,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'],
      menuId: json['menu_id'],
      // Use 'name' (new format) with fallback to 'item_name' (legacy)
      itemName: json['name'] ?? json['item_name'] ?? 'Unknown Item',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'],
      category: json['category'],
      available: json['available'] ?? true,
      picture: json['picture'],
      displayOrder: json['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_id': menuId,
      'name': itemName,
      'item_name': itemName, // Legacy field for backward compatibility
      'price': price,
      'description': description,
      'category': category,
      'available': available,
      'picture': picture,
      'display_order': displayOrder,
    };
  }
}

class MenuModel {
  final int id;
  final int barId;
  final String? name;
  final String? description;
  final bool isActive;
  final List<MenuItemModel> items;

  MenuModel({
    required this.id,
    required this.barId,
    this.name,
    this.description,
    this.isActive = true,
    required this.items,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'],
      barId: json['bar_id'],
      name: json['name'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => MenuItemModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bar_id': barId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      'is_active': isActive,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
