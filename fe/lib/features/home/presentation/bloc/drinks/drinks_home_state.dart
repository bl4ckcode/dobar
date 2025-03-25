import 'package:freezed_annotation/freezed_annotation.dart';

part 'drinks_home_state.freezed.dart';

@freezed
class DrinksHomeState with _$DrinksHomeState{
  const factory DrinksHomeState.initial() = Initial;
  const factory DrinksHomeState.loading() = Loading;
  const factory DrinksHomeState.success() = Success;
  const factory DrinksHomeState.failure({required String error}) = Failure;
}

