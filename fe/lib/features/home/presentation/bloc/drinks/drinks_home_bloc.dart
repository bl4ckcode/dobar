import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/home/domain/usecases/drinks_home_usecase.dart';
import '../../../../partners/domain/models/partner/partners_params.dart';
import 'drinks_home_event.dart';
import 'drinks_home_state.dart';
import 'drinks_model_mapper.dart';

class DrinksHomeBloc extends Bloc<DrinksHomeEvent, DrinksHomeState> {
  final DrinksHomeUseCase drinksHomeUseCase;

  DrinksHomeBloc({
    required this.drinksHomeUseCase,
  }) : super(
          const DrinksHomeState.initial(),
        ) {
    on<DrinksHomeLoadPartners>(_onLoadPartners);
  }

  Future<void> _onLoadPartners(
    DrinksHomeLoadPartners event,
    Emitter<DrinksHomeState> emit,
  ) async {
    emit(DrinksHomeState.loading()); // Trigger loading state

    final result = await drinksHomeUseCase.getPartners(
      PartnersParams(
        latitude: event.latitude,
        longitude: event.longitude,
        maxDistance: event.maxDistance,
      ),
    );
    result.fold(
      (failure) => emit(
        DrinksHomeState.failure(error: failure.errorMessage),
      ),
      (data) => emit(
        DrinksHomeState.success(mapPartnersToUiModel(data)),
      ),
    );
  }
}
