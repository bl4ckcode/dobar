import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/bars/presentation/bloc/bar_event.dart';
import 'package:barz/features/bars/presentation/bloc/bar_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BarBloc extends Bloc<BarEvent, BarState> {
  final BarUsecase barUsecase;

  BarBloc({required this.barUsecase}) : super(BarInitial()) {
    on<LoadNearbyBars>(_onLoadNearbyBars);
    on<LoadBar>(_onLoadBar);
    on<LoadBarMenus>(_onLoadBarMenus);
  }

  Future<void> _onLoadNearbyBars(
      LoadNearbyBars event, Emitter<BarState> emit) async {
    emit(BarLoading());
    final result =
        await barUsecase.getNearbyBars(event.lat, event.lng, event.maxDistance);
    result.fold(
      (failure) => emit(BarError(message: failure.errorMessage)),
      (bars) => emit(BarsLoaded(bars: bars)),
    );
  }

  Future<void> _onLoadBar(LoadBar event, Emitter<BarState> emit) async {
    emit(BarLoading());
    final result = await barUsecase.getBar(event.barId);
    result.fold(
      (failure) => emit(BarError(message: failure.errorMessage)),
      (bar) => emit(BarLoaded(bar: bar)),
    );
  }

  Future<void> _onLoadBarMenus(
      LoadBarMenus event, Emitter<BarState> emit) async {
    emit(BarLoading());
    final result = await barUsecase.getBarMenus(event.barId);
    result.fold(
      (failure) => emit(BarError(message: failure.errorMessage)),
      (menus) => emit(MenusLoaded(menus: menus)),
    );
  }
}
