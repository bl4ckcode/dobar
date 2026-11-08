import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/home/presentation/cubit/profile_account_cubit.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_edit_page.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Users extends Mock implements UserUsecase {}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'account waits for real data; failed save retains draft without claiming success',
    (tester) async {
      final users = Users();
      final user = UserModel(
        id: 7,
        displayName: 'Ana',
        email: 'ana@example.com',
        phoneNumber: '31999999999',
      );
      when(() => users.getCurrentUser()).thenAnswer((_) async => Right(user));
      when(
        () => users.updateProfile(displayName: 'Ana Maria'),
      ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
      final cubit = ProfileAccountCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          theme: getBarzLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const ProfileEditPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Alterações salvas.'), findsNothing);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Ana Maria');
      await tester.ensureVisible(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Maria'), findsOneWidget);
      expect(find.text('Alterações salvas.'), findsNothing);
      expect(
        find.text('Não foi possível concluir. Tente novamente.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        find.text('As alterações não salvas serão perdidas.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Descartar alterações').last);
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
    },
  );
}
