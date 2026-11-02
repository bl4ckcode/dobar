import 'dart:async';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Usecase extends Mock implements SessionUsecase {}

class _Login extends Mock implements LoginUsecase {}

void main() {
  test(
    'concurrent entry requests share initialization; error waits for explicit retry',
    () async {
      final usecase = _Usecase();
      final pending = Completer<Either<Failure, UserSession>>();
      when(usecase.initializeSession).thenAnswer((_) => pending.future);
      final bloc = SessionBloc(sessionUsecase: usecase, loginUsecase: _Login());
      final first = bloc.initializeForEntry();
      final second = bloc.initializeForEntry();
      await Future<void>.delayed(Duration.zero);
      verify(usecase.initializeSession).called(1);
      pending.complete(const Left(ServerFailure('offline', 503)));
      expect(await first, isA<SessionError>());
      expect(await second, isA<SessionError>());
      expect(await bloc.initializeForEntry(), isA<SessionError>());
      verifyNever(usecase.initializeSession);
      when(
        usecase.initializeSession,
      ).thenAnswer((_) async => Right(UserSession.empty()));
      expect(await bloc.initializeForEntry(force: true), isA<SessionReady>());
      await bloc.close();
    },
  );
  test(
    'Back sign-out awaits logout and stale initialization cannot restore session',
    () async {
      final usecase = _Usecase();
      final login = _Login();
      final pending = Completer<Either<Failure, UserSession>>();
      final logout = Completer<Either<Failure, void>>();
      when(usecase.initializeSession).thenAnswer((_) => pending.future);
      when(login.logout).thenAnswer((_) => logout.future);
      final bloc = SessionBloc(sessionUsecase: usecase, loginUsecase: login);
      final initialized = bloc.initializeForEntry();
      await Future<void>.delayed(Duration.zero);
      var finished = false;
      final signingOut = bloc.signOut().then((_) {
        finished = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      logout.complete(const Right(null));
      await signingOut;
      expect(await initialized, isA<SessionLoggedOut>());
      pending.complete(Right(UserSession.empty()));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<SessionLoggedOut>());
      await bloc.close();
    },
  );
}
