import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/home/presentation/cubit/profile_privacy_cubit.dart';
import 'package:barz/features/user/domain/models/privacy_settings.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Users extends Mock implements UserUsecase {}

void main() {
  setUpAll(() => registerFallbackValue(const PrivacySettings()));

  test(
    'load failure exposes no fabricated defaults and retry loads server values',
    () async {
      final users = Users();
      var n = 0;
      when(() => users.getPrivacySettings()).thenAnswer((_) async {
        n++;
        return n == 1
            ? const Left(NetworkFailure('offline'))
            : const Right(PrivacySettings(locationEnabled: true));
      });
      final cubit = ProfilePrivacyCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.settings, isNull);
      expect(cubit.state.failed, isTrue);
      await cubit.load();
      expect(cubit.state.settings!.locationEnabled, isTrue);
      expect(cubit.state.settings!.dataSharingEnabled, isFalse);
    },
  );

  test(
    'save persists through the server response; failure keeps the draft',
    () async {
      final users = Users();
      when(
        () => users.getPrivacySettings(),
      ).thenAnswer((_) async => const Right(PrivacySettings()));
      var ok = false;
      when(() => users.updatePrivacySettings(any())).thenAnswer(
        (i) async => ok
            ? Right(i.positionalArguments.first as PrivacySettings)
            : const Left(NetworkFailure('x')),
      );
      final cubit = ProfilePrivacyCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      cubit.change(cubit.state.settings!.copyWith(dataSharingEnabled: true));
      await cubit.save();
      expect(cubit.state.failed, isTrue);
      expect(cubit.state.settings!.dataSharingEnabled, isTrue);
      ok = true;
      await cubit.save();
      expect(cubit.state.saved, isTrue);
      verify(() => users.updatePrivacySettings(any())).called(2);
    },
  );
}
