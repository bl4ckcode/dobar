import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/models/menu_model.dart';
import 'package:equatable/equatable.dart';

abstract class BarState extends Equatable {
  const BarState();

  @override
  List<Object?> get props => [];
}

class BarInitial extends BarState {}

class BarLoading extends BarState {}

class BarsLoaded extends BarState {
  final List<BarModel> bars;

  const BarsLoaded({required this.bars});

  @override
  List<Object?> get props => [bars];
}

class BarLoaded extends BarState {
  final BarModel bar;

  const BarLoaded({required this.bar});

  @override
  List<Object?> get props => [bar];
}

class MenusLoaded extends BarState {
  final List<MenuModel> menus;

  const MenusLoaded({required this.menus});

  @override
  List<Object?> get props => [menus];
}

class BarError extends BarState {
  final String message;

  const BarError({required this.message});

  @override
  List<Object?> get props => [message];
}
