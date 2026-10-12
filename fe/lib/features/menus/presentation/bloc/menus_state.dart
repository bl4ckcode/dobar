import 'package:barz/features/partners/domain/models/partner/product.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'menus_state.freezed.dart';

@freezed
sealed class MenusState with _$MenusState {
  const factory MenusState.initial() = Initial;
  const factory MenusState.loading() = Loading;
  const factory MenusState.successWithItems(List<Product> items) =
      SuccessWithItems;
  const factory MenusState.failure({required String error}) = Failure;
}
