import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';
import 'package:barz/features/home/domain/usecases/home_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeUseCase homeUseCase;

  int currentPage = 0;

  HomeBloc({required this.homeUseCase}) : super(LoadingGetHomeState()) {
    on<OnGettingHomeEvent>(_onGettingHomeEvent);
  }

  _onGettingHomeEvent(
      OnGettingHomeEvent event, Emitter<HomeState> emitter) async {
    if (event.withLoading) {
      emitter(LoadingGetHomeState());
    }

    final result = await homeUseCase.call(
      HomeParams(
        identification: event.identification,
      ),
    );
    result.fold((l) {
      emitter(ErrorGetHomeState(l.errorMessage));
    }, (r) {
      emitter(SuccessGetHomeState(r));
    });
  }
}
