import 'package:freezed_annotation/freezed_annotation.dart';

part 'menus_event.freezed.dart';

@freezed
sealed class MenusEvent with _$MenusEvent {
  const factory MenusEvent.loadMenuPartners({required int barID}) =
      MenusLoadPartners;
}
