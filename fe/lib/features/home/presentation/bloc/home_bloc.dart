import 'package:barz/features/home/data/repositories/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository repository;

  HomeBloc(this.repository) : super(const HomeState.initial()) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeState.loading());
    final result = await repository.getHomeData(latitude: event.latitude, longitude: event.longitude);
    result.fold(
      (failure) =>
          emit(HomeState.error(message: failure.message ?? 'Unknown error')),
      (data) => emit(HomeState.loaded(data: data)),
    );
  }
}
