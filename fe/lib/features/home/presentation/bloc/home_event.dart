part of 'home_bloc.dart';

abstract class HomeEvent {
  const HomeEvent();
}

// On Fetching Articles Event
class OnGettingHomeEvent extends HomeEvent {
  final String identification;
  final bool withLoading;

  OnGettingHomeEvent(this.identification, {this.withLoading = true});
}