import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_event.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';

class _Usecase extends Mock implements SessionUsecase {}

class _Login extends Mock implements LoginUsecase {}

const access = BarAccess(
  barId: 42,
  barName: 'Created bar',
  role: BarRole.owner,
  permissions: {},
);
void main() {
  late _Usecase usecase;
  late SessionBloc bloc;
  setUp(() async {
    usecase = _Usecase();
    when(
      () => usecase.initializeSession(),
    ).thenAnswer((_) async => Right(UserSession.empty()));
    bloc = SessionBloc(sessionUsecase: usecase, loginUsecase: _Login());
    final ready = bloc.stream.firstWhere((s) => s is SessionReady);
    bloc.add(const SessionEvent.initialize());
    await ready;
  });
  tearDown(() => bloc.close());
  test(
    'refresh selects exactly the returned venue and updates full access list',
    () async {
      when(
        () => usecase.refreshBarAccess(),
      ).thenAnswer((_) async => const Right([access]));
      expect(await bloc.refreshAndSelectVenue(42), true);
      expect(bloc.state.currentSession!.activeBar!.barId, 42);
      expect(bloc.state.currentSession!.barAccess.length, 1);
      expect(await bloc.refreshAndSelectVenue(42), true);
      expect(bloc.state.currentSession!.barAccess.length, 1);
    },
  );
  test('failed or missing access never enters the requested venue', () async {
    when(
      () => usecase.refreshBarAccess(),
    ).thenAnswer((_) async => const Left(ServerFailure('offline', null)));
    expect(await bloc.refreshAndSelectVenue(42), false);
    when(
      () => usecase.refreshBarAccess(),
    ).thenAnswer((_) async => const Right([]));
    expect(await bloc.refreshAndSelectVenue(42), false);
    expect(bloc.state.currentSession!.activeBar, null);
  });
}
