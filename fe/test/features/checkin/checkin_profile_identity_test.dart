import 'package:barz/features/authentication/domain/usecases/login_usecase.dart';
import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/cart/domain/models/cart_models.dart';
import 'package:barz/features/checkin/data/repositories/checkin_network_repository.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_bloc.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'package:barz/features/session/data/datasources/session_datasource.dart';
import 'package:barz/features/session/data/repositories/session_repository_impl.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/user/data/data_sources/user_network_datasource.dart';
import 'package:barz/features/user/data/repositories/user_repository_impl.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../payments/checkout_recovery_test.dart'
    show ScriptedAdapter, jsonResponse;

class _Bars extends Mock implements AbstractBarRepository {}

class _Location extends Mock implements LocationUsecase {}

class _Login extends Mock implements LoginUsecase {}

void main() {
  test(
    'restored session hydrates profile identity before confirming check-in',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..httpClientAdapter = ScriptedAdapter((request) async {
          requests.add(request);
          if (request.path.endsWith('/me/profile')) {
            return jsonResponse({
              'id': 501,
              'display_name': 'Cliente',
              'user_type': 'client',
              'country_code': 'BR',
              'terms_accepted': true,
              'privacy_accepted': true,
            });
          }
          if (request.path.endsWith('/checkins')) {
            return jsonResponse({
              'id': 10,
              'user_id': 501,
              'bar_id': 7,
              'bar_name': 'Bar',
              'status': 'active',
              'checked_in_at': DateTime.now().toIso8601String(),
              'expires_at': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            });
          }
          if (request.path.endsWith('/documents') ||
              request.path.endsWith('/me/bars') ||
              request.path.endsWith('/invitations/pending')) {
            return jsonResponse([]);
          }
          fail('Unexpected request: ${request.method} ${request.path}');
        });
      final session = SessionBloc(
        sessionUsecase: SessionUsecase(
          sessionRepository: SessionRepositoryImpl(
            SessionNetworkDatasource(dio: dio),
          ),
          userRepository: UserRepositoryImpl(UserNetworkDatasource(dio: dio)),
        ),
        loginUsecase: _Login(),
      );
      addTearDown(session.close);
      // Cached-token entry initializes the session without invoking login.
      await session.initializeForEntry();
      expect(session.state.currentSession?.user.id, 501);
      final bars = _Bars();
      final location = _Location();
      when(() => bars.getLocationConfig(7)).thenAnswer(
        (_) async =>
            const Right(LocationConfig(method: LocationMethod.tableNumber)),
      );
      when(
        () => location.checkLocationPermission(),
      ).thenAnswer((_) async => const Right(true));
      when(() => location.getCurrentLocation()).thenAnswer(
        (_) async => Right(
          LocationModel(
            latitude: -19.9,
            longitude: -43.9,
            timestamp: DateTime.now(),
            accuracy: 3,
          ),
        ),
      );
      final checkin = CheckinBloc(
        barUsecase: BarUsecase(repository: bars),
        bars: bars,
        repository: CheckinNetworkRepository(dio),
        location: location,
        session: session,
      );
      addTearDown(checkin.close);
      final selected = checkin.stream.firstWhere(
        (s) => s.locationConfig != null,
      );
      checkin.add(
        SelectBar(
          BarModel(
            id: 7,
            name: 'Bar',
            address: 'Rua',
            phoneNumber: '',
            email: '',
          ),
        ),
      );
      await selected;
      final confirmed = checkin.stream.firstWhere(
        (s) => s.isCheckedIn || s.error != null,
      );
      checkin.add(const ConfirmCheckin());
      await confirmed;
      expect(checkin.state.error, isNull);
      expect(checkin.state.activeCheckin?.userId, 501);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.path.endsWith('/checkins'),
        ),
        hasLength(1),
      );
    },
  );
}
