import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/services/biometry_service.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/authentication/presentation/pages/login_page.dart';
import 'package:barz/features/user/domain/repositories/abstract_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUsecase extends Mock implements LoginUsecase {}

class MockUserRepository extends Mock implements UserRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockBiometryService extends Mock implements BiometryService {}

void main() {
  setUp(() async {
    await getItInjector.reset();
    getItInjector
      ..registerSingleton<LoginUsecase>(MockLoginUsecase())
      ..registerSingleton<UserRepository>(MockUserRepository())
      ..registerSingleton<FirebaseAuth>(MockFirebaseAuth())
      ..registerSingleton<BiometryService>(MockBiometryService());
  });

  tearDown(() => getItInjector.reset());

  testWidgets('mounts as the initial route without inherited-widget errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: getBarzLightTheme(), home: const LoginPage()),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
