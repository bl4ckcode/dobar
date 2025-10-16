import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/menus_usecase.dart';
import 'menus_event.dart';
import 'menus_state.dart';

class MenusBloc extends Bloc<MenusEvent, MenusState> {
  final MenusUseCase menusUseCase;
  StreamSubscription? _menuSubscription;

  MenusBloc({
    required this.menusUseCase,
  }) : super(const MenusState.initial()) {
    on<MenusLoadPartners>(_onLoadMenuPartners);
  }

  Future<void> _onLoadMenuPartners(
      MenusLoadPartners event,
      Emitter<MenusState> emit,
      ) async {
    emit(const MenusState.loading());

    _menuSubscription?.cancel();

    _menuSubscription = menusUseCase.subscribeToMenu(event.barID).listen(
          (result) {
        result.fold(
              (failure) => emit(MenusState.failure(error: failure.errorMessage)),
              (items) => emit(MenusState.successWithItems(items)),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _menuSubscription?.cancel();
    return super.close();
  }
}
