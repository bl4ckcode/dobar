import 'package:freezed_annotation/freezed_annotation.dart';

part 'menus_state.freezed.dart';

@freezed
sealed class MenusState with _$MenusState {
  const factory MenusState.initial() = Initial;
  const factory MenusState.loading() = Loading;
  const factory MenusState.success() = Success;
  const factory MenusState.failure({required String error}) = Failure;
}

