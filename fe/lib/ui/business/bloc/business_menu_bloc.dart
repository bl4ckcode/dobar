import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/bars/data/data_sources/bar_network_datasource.dart';
import 'business_menu_event.dart';
import 'business_menu_state.dart';

class BusinessMenuBloc extends Bloc<BusinessMenuEvent, BusinessMenuState> {
  final BarNetworkDataSource _dataSource;

  BusinessMenuBloc({BarNetworkDataSource? dataSource})
    : _dataSource = dataSource ?? getItInjector<BarNetworkDataSource>(),
      super(const BusinessMenuState()) {
    on<LoadMenus>(_onLoadMenus);
    on<RefreshMenus>(_onRefreshMenus);
    on<DeleteMenuItem>(_onDeleteMenuItem);
    on<UpdateMenuItem>(_onUpdateMenuItem);
    on<ToggleItemAvailability>(_onToggleItemAvailability);
    on<DeleteMenu>(_onDeleteMenu);
  }

  Future<void> _onLoadMenus(
    LoadMenus event,
    Emitter<BusinessMenuState> emit,
  ) async {
    emit(
      state.copyWith(status: BusinessMenuStatus.loading, barId: event.barId),
    );

    try {
      final menus = await _dataSource.getBarMenusWithItems(event.barId);
      emit(state.copyWith(status: BusinessMenuStatus.loaded, menus: menus));
    } catch (e) {
      emit(
        state.copyWith(
          status: BusinessMenuStatus.error,
          errorMessage: 'Failed to load menus: $e',
        ),
      );
    }
  }

  Future<void> _onRefreshMenus(
    RefreshMenus event,
    Emitter<BusinessMenuState> emit,
  ) async {
    if (state.barId == null) return;
    add(LoadMenus(state.barId!));
  }

  Future<void> _onDeleteMenuItem(
    DeleteMenuItem event,
    Emitter<BusinessMenuState> emit,
  ) async {
    try {
      await _dataSource.deleteMenuItem(event.menuId, event.itemId);
      if (state.barId != null) {
        add(LoadMenus(state.barId!));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete item: $e'));
    }
  }

  Future<void> _onUpdateMenuItem(
    UpdateMenuItem event,
    Emitter<BusinessMenuState> emit,
  ) async {
    try {
      await _dataSource.updateMenuItem(
        event.menuId,
        event.itemId,
        name: event.name,
        description: event.description,
        price: event.price,
        category: event.category,
      );
      if (state.barId != null) {
        add(LoadMenus(state.barId!));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update item: $e'));
    }
  }

  Future<void> _onToggleItemAvailability(
    ToggleItemAvailability event,
    Emitter<BusinessMenuState> emit,
  ) async {
    try {
      await _dataSource.updateItemAvailability(
        event.menuId,
        event.itemId,
        event.isAvailable,
      );
      if (state.barId != null) {
        add(LoadMenus(state.barId!));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update item: $e'));
    }
  }

  Future<void> _onDeleteMenu(
    DeleteMenu event,
    Emitter<BusinessMenuState> emit,
  ) async {
    try {
      await _dataSource.deleteMenu(event.menuId);
      if (state.barId != null) {
        add(LoadMenus(state.barId!));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete menu: $e'));
    }
  }
}
