import 'package:equatable/equatable.dart';

abstract class BarEvent extends Equatable {
  const BarEvent();

  @override
  List<Object?> get props => [];
}

class LoadNearbyBars extends BarEvent {
  final double lat;
  final double lng;
  final double maxDistance;

  const LoadNearbyBars({
    required this.lat,
    required this.lng,
    this.maxDistance = 250000,
  });

  @override
  List<Object?> get props => [lat, lng, maxDistance];
}

class LoadBar extends BarEvent {
  final int barId;

  const LoadBar({required this.barId});

  @override
  List<Object?> get props => [barId];
}

class LoadBarMenus extends BarEvent {
  final int barId;

  const LoadBarMenus({required this.barId});

  @override
  List<Object?> get props => [barId];
}
