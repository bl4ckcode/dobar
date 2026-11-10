import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_event.freezed.dart';

@freezed
sealed class HomeEvent with _$HomeEvent {
  /// [force] bypasses the cached aggregate (pull-to-refresh, account/benefit/
  /// notification/purchase changes). Location changes bypass it automatically.
  const factory HomeEvent.loadHomeData({
    double? latitude,
    double? longitude,
    @Default(false) bool force,
  }) = LoadHomeData;
}
