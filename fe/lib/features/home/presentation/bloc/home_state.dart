import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/home/domain/models/home_model.dart';

part 'home_state.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.initial() = HomeInitial;
  const factory HomeState.loading() = HomeLoading;
  const factory HomeState.loaded({required HomeModel data}) = HomeLoaded;
  const factory HomeState.error({required String message}) = HomeError;
}
