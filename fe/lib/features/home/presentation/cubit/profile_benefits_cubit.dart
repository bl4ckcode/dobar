import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/user/domain/models/profile_benefit.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum BenefitsLoadStatus { loading, loaded, failed, unauthorized }

bool isUnauthorizedFailure(Failure failure) =>
    failure is ServerFailure &&
    (failure.statusCode == 401 || failure.statusCode == 403);

class ProfileBenefitsState {
  const ProfileBenefitsState({
    this.status = BenefitsLoadStatus.loading,
    this.data,
  });
  final BenefitsLoadStatus status;
  final ProfileBenefits? data;

  /// Real active count only; null until the authenticated source answers.
  int? get activeCount => status == BenefitsLoadStatus.loaded
      ? data?.activeCount
      : null;
}

/// Loads owned benefits. Never redeems or applies a benefit.
class ProfileBenefitsCubit extends Cubit<ProfileBenefitsState> {
  ProfileBenefitsCubit(this._users) : super(const ProfileBenefitsState());
  final UserUsecase _users;

  Future<void> load() async {
    emit(const ProfileBenefitsState());
    final result = await _users.getBenefits();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        ProfileBenefitsState(
          status: isUnauthorizedFailure(failure)
              ? BenefitsLoadStatus.unauthorized
              : BenefitsLoadStatus.failed,
        ),
      ),
      (data) => emit(
        ProfileBenefitsState(status: BenefitsLoadStatus.loaded, data: data),
      ),
    );
  }
}

class BenefitVenuesState {
  const BenefitVenuesState({
    this.status = BenefitsLoadStatus.loading,
    this.data,
  });
  final BenefitsLoadStatus status;
  final BenefitVenues? data;
}

/// Authoritative eligible venues for exactly one benefit id.
class BenefitVenuesCubit extends Cubit<BenefitVenuesState> {
  BenefitVenuesCubit(this._users, this.benefitId)
    : super(const BenefitVenuesState());
  final UserUsecase _users;
  final String benefitId;

  Future<void> load() async {
    emit(const BenefitVenuesState());
    final result = await _users.getBenefitVenues(benefitId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        BenefitVenuesState(
          status: isUnauthorizedFailure(failure)
              ? BenefitsLoadStatus.unauthorized
              : BenefitsLoadStatus.failed,
        ),
      ),
      (data) => emit(
        BenefitVenuesState(status: BenefitsLoadStatus.loaded, data: data),
      ),
    );
  }
}
