import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/home/presentation/cubit/profile_account_cubit.dart';
import 'package:barz/features/home/presentation/cubit/profile_settings_cubit.dart';
import 'package:barz/features/payments/domain/models/payment_method.dart';
import 'package:barz/features/payments/domain/usecases/payment_usecase.dart';
import 'package:barz/features/payments/presentation/bloc/payment_bloc.dart';
import 'package:barz/features/payments/presentation/bloc/payment_event.dart';
import 'package:barz/features/user/domain/models/notification_preferences.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Users extends Mock implements UserUsecase {}

class Payments extends Mock implements PaymentUsecase {}

void main() {
  test(
    'account save preserves an existing avatar and failure preserves loaded identity',
    () async {
      final users = Users();
      final user = UserModel(
        id: 7,
        displayName: 'Ana',
        profilePictureUrl: 'existing-avatar',
      );
      when(() => users.getCurrentUser()).thenAnswer((_) async => Right(user));
      when(
        () => users.updateProfile(displayName: 'Ana Maria'),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      final cubit = ProfileAccountCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.save(' Ana Maria ');
      expect(cubit.state.user, same(user));
      expect(cubit.state.error, 'offline');
      expect(cubit.state.saved, isFalse);
      verify(() => users.updateProfile(displayName: 'Ana Maria')).called(1);
    },
  );

  test(
    'failed deletion retains account and never reports completion',
    () async {
      final users = Users();
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => Right(UserModel(id: 7)));
      when(
        () => users.deleteAccount(),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      final cubit = ProfileAccountCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.delete();
      expect(cubit.state.deleted, isFalse);
      expect(cubit.state.user?.id, 7);
      expect(cubit.state.error, 'offline');
    },
  );

  test(
    'notification load failure offers retry, and failed save retains draft',
    () async {
      final users = Users();
      const prefs = NotificationPreferences(pushNotificationsEnabled: false);
      when(
        () => users.getNotificationPreferences(),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      final cubit = ProfileSettingsCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.preferences, isNull);
      expect(cubit.state.failed, isTrue);
      when(
        () => users.getNotificationPreferences(),
      ).thenAnswer((_) async => const Right(prefs));
      await cubit.load();
      final draft = prefs.copyWith(promotionsEnabled: false);
      cubit.change(draft);
      when(
        () => users.updateNotificationPreferences(draft),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      await cubit.save();
      expect(cubit.state.preferences, same(draft));
      expect(cubit.state.saved, isFalse);
      expect(cubit.state.failed, isTrue);
    },
  );

  for (final addFails in [true, false]) {
    test(
      'replacement ${addFails ? 'add failure preserves old card' : 'remove failure preserves both cards'}',
      () async {
        final payments = Payments();
        final old = PaymentMethod(
          gateway: PaymentGateway.pagarme,
          type: PaymentType.credit,
          id: 1,
          lastFourDigits: '1111',
        );
        final replacement = PaymentMethod(
          gateway: PaymentGateway.pagarme,
          type: PaymentType.credit,
          id: 2,
          lastFourDigits: '2222',
        );
        var saved = [old];
        when(
          () => payments.getSavedCards(),
        ).thenAnswer((_) async => Right(saved));
        when(
          () => payments.addSavedCard(
            cardToken: 'provider-token',
            lastFour: '2222',
            brand: 'Visa',
            expMonth: 12,
            expYear: 2030,
            isDefault: false,
          ),
        ).thenAnswer((_) async {
          if (addFails) return const Left(NetworkFailure('offline'));
          saved = [old, replacement];
          return Right(replacement);
        });
        when(
          () => payments.deleteSavedCard(1),
        ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
        final bloc = PaymentBloc(payments);
        addTearDown(bloc.close);
        final loaded = bloc.stream.firstWhere((s) => s.savedCards.isNotEmpty);
        bloc.add(const LoadSavedCards());
        await loaded;
        final done = bloc.stream.firstWhere(
          (s) => !s.isProcessing && s.error != null,
        );
        bloc.add(
          const AddSavedCard(
            cardToken: 'provider-token',
            lastFour: '2222',
            brand: 'Visa',
            expMonth: 12,
            expYear: 2030,
            replacementCardId: 1,
          ),
        );
        await done;
        expect(bloc.state.savedCards.map((c) => c.id), addFails ? [1] : [1, 2]);
        if (addFails) {
          verifyNever(() => payments.deleteSavedCard(any()));
        } else {
          expect(bloc.state.error, 'saved_card_replacement_remove_failed');
          verify(() => payments.deleteSavedCard(1)).called(1);
        }
      },
    );
  }
}
