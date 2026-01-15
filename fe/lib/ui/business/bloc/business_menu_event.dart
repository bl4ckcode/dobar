abstract class BusinessMenuEvent {}

class LoadMenus extends BusinessMenuEvent {
  final int barId;
  LoadMenus(this.barId);
}

class DeleteMenuItem extends BusinessMenuEvent {
  final int menuId;
  final int itemId;
  DeleteMenuItem({required this.menuId, required this.itemId});
}

class UpdateMenuItem extends BusinessMenuEvent {
  final int menuId;
  final int itemId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  UpdateMenuItem({
    required this.menuId,
    required this.itemId,
    required this.name,
    this.description,
    required this.price,
    this.category,
  });
}

class ToggleItemAvailability extends BusinessMenuEvent {
  final int menuId;
  final int itemId;
  final bool isAvailable;
  ToggleItemAvailability({
    required this.menuId,
    required this.itemId,
    required this.isAvailable,
  });
}

class RefreshMenus extends BusinessMenuEvent {}

class DeleteMenu extends BusinessMenuEvent {
  final int menuId;
  DeleteMenu({required this.menuId});
}