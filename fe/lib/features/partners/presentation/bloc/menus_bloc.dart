import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/menus_usecase.dart';
import 'menus_event.dart';
import 'menus_state.dart';

class MenusBloc extends Bloc<MenusEvent, MenusState> {
  final MenusUseCase menusUseCase;

  MenusBloc({required this.menusUseCase}) : super(const MenusState.initial()) {
    on<MenusLoadPartners>(_onLoadMenuPartners);

    add(MenusLoadPartners(barID: 123));
  }

  Future<void> _onLoadMenuPartners(
    MenusLoadPartners event,
    Emitter<MenusState> emit,
  ) async {
    emit(MenusState.loading()); // Trigger loading state
    final result = await menusUseCase.getPartnerMenus(event.barID);
    result.fold(
      (failure) => emit(MenusState.failure(error: failure.errorMessage)),
      (data) => emit(MenusState.success()),
    );
  }
}
