import 'dart:async';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/checkin/domain/models/checkin_model.dart';
import 'package:barz/features/checkin/domain/repositories/checkin_repository.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBars extends Mock implements AbstractBarRepository {}

class MockCheckins extends Mock implements CheckinRepository {}

class MockLocation extends Mock implements LocationUsecase {}

class MockSession extends Mock implements SessionBloc {}

void main() {
  late MockBars bars;
  late MockCheckins repository;
  late MockLocation location;
  late MockSession session;
  late StreamController<SessionState> sessionChanges;
  late SessionState sessionState;
  late CheckinBloc bloc;
  final bar = BarModel(
    id: 7,
    name: 'Bar',
    address: 'Rua',
    phoneNumber: '',
    email: '',
  );
  final fix = LocationModel(
    latitude: -19.9,
    longitude: -43.9,
    timestamp: DateTime.utc(2026, 11, 3, 12),
    accuracy: 3,
  );
  CheckinModel active({int userId = 5, int barId = 7, DateTime? expiresAt}) =>
      CheckinModel(
        id: 10,
        userId: userId,
        barId: barId,
        barName: 'Bar',
        status: CheckinStatus.active,
        checkedInAt: DateTime.now(),
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      );

  setUpAll(() {
    registerFallbackValue(fix);
  });
  setUp(() {
    bars = MockBars();
    repository = MockCheckins();
    location = MockLocation();
    session = MockSession();
    sessionChanges = StreamController<SessionState>.broadcast();
    sessionState = SessionState.ready(
      session: UserSession(user: UserModel(id: 5)),
    );
    when(() => session.state).thenAnswer((_) => sessionState);
    when(() => session.stream).thenAnswer((_) => sessionChanges.stream);
    bloc = CheckinBloc(
      barUsecase: BarUsecase(repository: bars),
      bars: bars,
      repository: repository,
      location: location,
      session: session,
    );
  });
  tearDown(() async {
    await bloc.close();
    await sessionChanges.close();
  });

  test(
    'only authenticated server checkin matching venue authorizes an order',
    () async {
      when(() => repository.getActive()).thenAnswer((_) async => active());
      expect(await bloc.refresh(barId: 7), isTrue);
      expect(await bloc.refresh(barId: 8), isFalse);
      when(
        () => repository.getActive(),
      ).thenAnswer((_) async => active(userId: 0));
      expect(await bloc.refresh(barId: 7), isFalse);
      expect(bloc.state.isCheckedIn, isFalse);
      when(() => repository.getActive()).thenAnswer(
        (_) async => active(
          expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );
      expect(await bloc.refresh(barId: 7), isFalse);
    },
  );

  test(
    'confirmation forwards actual fix timestamp and selected table to server',
    () async {
      when(() => bars.getLocationConfig(7)).thenAnswer(
        (_) async =>
            const Right(LocationConfig(method: LocationMethod.tableNumber)),
      );
      when(
        () => location.checkLocationPermission(),
      ).thenAnswer((_) async => const Right(true));
      when(
        () => location.getCurrentLocation(),
      ).thenAnswer((_) async => Right(fix));
      when(
        () => repository.confirm(barId: 7, location: fix, tableNumber: '3'),
      ).thenAnswer((_) async => active());
      final selected = bloc.stream.firstWhere(
        (state) => state.locationConfig != null,
      );
      bloc.add(SelectBar(bar));
      await selected;
      final tableSet = bloc.stream.firstWhere(
        (state) => state.tableNumber == '3',
      );
      bloc.add(const SetTableNumber('3'));
      await tableSet;
      final checkedIn = bloc.stream.firstWhere((state) => state.isCheckedIn);
      bloc.add(const ConfirmCheckin());
      await checkedIn;
      verify(
        () => repository.confirm(barId: 7, location: fix, tableNumber: '3'),
      ).called(1);
      expect(bloc.state.activeCheckin!.userId, 5);
    },
  );

  test(
    'logout clears active session without trusting another user local data',
    () async {
      when(() => repository.getActive()).thenAnswer((_) async => active());
      await bloc.refresh(barId: 7);
      final cleared = bloc.stream.firstWhere((state) => !state.isCheckedIn);
      sessionState = const SessionState.loggedOut();
      sessionChanges.add(sessionState);
      await cleared;
      expect(await bloc.refresh(barId: 7), isFalse);
    },
  );

  test('QR links reject unrelated hosts and preserve real table selection', () {
    expect(
      () => QrScanResult.fromQrCode('https://unrelated.example/bar/7?table=3'),
      throwsFormatException,
    );
    final parsed = QrScanResult.fromQrCode('https://dobar.app/bar/7?table=3');
    expect(parsed.barId, 7);
    expect(parsed.tableNumber, '3');
  });
}
