part of 'home_bloc.dart';

abstract class HomeState {
  const HomeState();
}

class HomeInitial extends HomeState {}

class LoadingGetHomeState extends HomeState {}

class ErrorGetHomeState extends HomeState {
  final String errorMsg;

  ErrorGetHomeState(this.errorMsg);
}

class SuccessGetHomeState extends HomeState {
  final HomeModel? homeModel;

  SuccessGetHomeState(this.homeModel);
}
