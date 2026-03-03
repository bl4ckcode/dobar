import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_orders_state.freezed.dart';

@freezed
class LiveOrdersState with _$LiveOrdersState {
  const factory LiveOrdersState.initial() = _Initial;
  const factory LiveOrdersState.loading() = _Loading;
  const factory LiveOrdersState.loaded(dynamic orders) = _Loaded;
  const factory LiveOrdersState.error(String message) = _Error;
}
