import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String errorMessage;

  const Failure(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.errorMessage, this.statusCode);
}

class CacheFailure extends Failure {
  const CacheFailure(super.errorMessage);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.errorMessage);
}

class SyncFailure extends Failure {
  final int pendingCount;
  
  const SyncFailure(super.errorMessage, {this.pendingCount = 0});
  
  @override
  List<Object> get props => [errorMessage, pendingCount];
}