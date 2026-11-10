import 'package:barz/core/session/shell_session.dart';
import 'package:barz/features/home/data/repositories/home_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository repository;
  final ShellSession session;

  int _seq = 0;
  String? _inFlightKey;

  HomeBloc(this.repository, this.session)
    // Tab return: show the cached aggregate immediately, no request.
    : super(
        session.homeData != null
            ? HomeState.loaded(data: session.homeData!)
            : const HomeState.initial(),
      ) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  static String _key(double? lat, double? lng) => lat == null || lng == null
      ? 'none'
      : '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';

  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    final key = _key(event.latitude, event.longitude);

    if (!event.force && session.homeFresh(event.latitude, event.longitude)) {
      if (state is! HomeLoaded) emit(HomeState.loaded(data: session.homeData!));
      return;
    }
    // Coalesce duplicate requests for the same area.
    if (_inFlightKey == key) return;

    final seq = ++_seq;
    _inFlightKey = key;
    if (state is! HomeLoaded) emit(const HomeState.loading());

    final result = await repository.getHomeData(
      latitude: event.latitude,
      longitude: event.longitude,
    );

    // A newer request superseded this one (or the bloc closed): drop it.
    if (seq != _seq || isClosed) return;
    _inFlightKey = null;

    result.fold(
      (failure) {
        if (state is HomeLoaded) return; // keep showing last good data
        emit(HomeState.error(message: failure.message ?? 'Unknown error'));
      },
      (data) {
        session.storeHome(data, event.latitude, event.longitude);
        emit(HomeState.loaded(data: data));
      },
    );
  }
}
