import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/onboarding/data/datasources/onboarding_datasource.dart';
import 'package:barz/features/onboarding/domain/models/onboarding_request.dart';
import 'package:barz/features/onboarding/domain/models/payment_gateway.dart';
import 'package:barz/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:dartz/dartz.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingDatasource datasource;

  OnboardingRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, UserModel>> completeOnboarding(
    OnboardingRequest request,
  ) async {
    try {
      final user = await datasource.completeOnboarding(request);
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  @override
  Future<Either<Failure, PaymentGateway>> getPaymentGateway() async {
    try {
      final gateway = await datasource.getPaymentGateway();
      return Right(gateway);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, e.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}
