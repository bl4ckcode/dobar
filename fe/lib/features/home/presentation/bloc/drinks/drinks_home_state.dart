import 'package:barz/shared/domain/models/parallax_recipe_ui_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'drinks_home_state.freezed.dart';

@freezed
sealed class DrinksHomeState with _$DrinksHomeState {
  const factory DrinksHomeState.initial() = Initial;
  const factory DrinksHomeState.loading() = Loading;
  const factory DrinksHomeState.success(List<ParallaxRecipeUiModel> partners) =
      Success;
  const factory DrinksHomeState.failure({required String error}) = Failure;
}
