import 'package:freezed_annotation/freezed_annotation.dart';

part 'drinks_home_event.freezed.dart';

@freezed
sealed class DrinksHomeEvent with _$DrinksHomeEvent {
  const factory DrinksHomeEvent.loadPartners({
    double? latitude,
    double? longitude,
    double? maxDistance,
  }) = DrinksHomeLoadPartners;
  const factory DrinksHomeEvent.cardClicked({required int partnerIdentifier}) =
      DrinksHomeCardClicked;
}
