import 'package:equatable/equatable.dart';

abstract class BarEvent extends Equatable {
  const BarEvent();

  @override
  List<Object?> get props => [];
}

class LoadNearbyBars extends BarEvent {
  final double latitude;
  final double longitude;
  final double maxDistance;

  const LoadNearbyBars({
    required this.latitude,
    required this.longitude,
    this.maxDistance = 250000,
  });

  @override
  List<Object?> get props => [latitude, longitude, maxDistance];
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
