import 'package:barz/features/bars/domain/models/menu_model.dart';

enum BusinessMenuStatus { initial, loading, loaded, error }

class BusinessMenuState {
  final BusinessMenuStatus status;
  final List<MenuModel> menus;
  final String? errorMessage;
  final int? barId;

  const BusinessMenuState({
    this.status = BusinessMenuStatus.initial,
    this.menus = const [],
    this.errorMessage,
    this.barId,
  });

  int get totalItems => menus.fold(0, (sum, menu) => sum + menu.items.length);

  BusinessMenuState copyWith({
    BusinessMenuStatus? status,
    List<MenuModel>? menus,
    String? errorMessage,
    int? barId,
  }) {
    return BusinessMenuState(
      status: status ?? this.status,
      menus: menus ?? this.menus,
      errorMessage: errorMessage,
      barId: barId ?? this.barId,
    );
  }
}
