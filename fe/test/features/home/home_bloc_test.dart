import 'dart:async';

import 'package:barz/core/error/error_codes.dart';
import 'package:barz/core/error/failures.dart';
import 'package:barz/core/session/shell_session.dart';
import 'package:barz/features/home/data/repositories/home_repository.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/presentation/bloc/home_bloc.dart';
import 'package:barz/features/home/presentation/bloc/home_event.dart';
import 'package:barz/features/home/presentation/bloc/home_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

HomeModel _model(String name) => HomeModel(
  locationMismatch: false,
  nearbyBars: const [],
  trendingDrinks: TrendingSection(mostWanted: [], hottest: []),
  activePromotions: const [],
  displayName: name,
);

class _Repo implements HomeRepository {
  final calls = <Completer<Either<Failure, HomeModel>>>[];
  final args = <(double?, double?)>[];

  @override
  Future<Either<Failure, HomeModel>> getHomeData({
    double? latitude,
    double? longitude,
  }) {
    args.add((latitude, longitude));
    final c = Completer<Either<Failure, HomeModel>>();
    calls.add(c);
    return c.future;
  }
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late _Repo repo;
  late ShellSession session;
  late HomeBloc bloc;

  setUp(() {
    repo = _Repo();
    session = ShellSession();
    bloc = HomeBloc(repo, session);
  });
  tearDown(() => bloc.close());

  test('loads without location (browsing needs no permission)', () async {
    bloc.add(const LoadHomeData());
    await _pump();
    expect(repo.args.single, (null, null));
    repo.calls.single.complete(Right(_model('Ana')));
    await _pump();
    expect(bloc.state, isA<HomeLoaded>());
  });

  test('duplicate requests for the same area are coalesced', () async {
    bloc.add(const LoadHomeData(latitude: -19.9, longitude: -43.9));
    bloc.add(const LoadHomeData(latitude: -19.9, longitude: -43.9));
    bloc.add(const LoadHomeData(latitude: -19.9001, longitude: -43.9001));
    await _pump();
    expect(repo.calls.length, 1);
  });

  test('stale response from an older request is discarded', () async {
    bloc.add(const LoadHomeData());
    await _pump();
    bloc.add(const LoadHomeData(latitude: -19.9, longitude: -43.9));
    await _pump();
    expect(repo.calls.length, 2);

    repo.calls[1].complete(Right(_model('new')));
    await _pump();
    repo.calls[0].complete(Right(_model('old'))); // arrives late
    await _pump();

    expect((bloc.state as HomeLoaded).data.displayName, 'new');
    expect(session.homeData!.displayName, 'new');
  });

  test('fresh cache is reused on return; force/stale refetches', () async {
    bloc.add(const LoadHomeData());
    await _pump();
    repo.calls.single.complete(Right(_model('Ana')));
    await _pump();

    final returning = HomeBloc(repo, session); // tab return builds a new bloc
    expect(returning.state, isA<HomeLoaded>());
    returning.add(const LoadHomeData());
    await _pump();
    expect(repo.calls.length, 1, reason: 'cached data reused, no request');

    session.invalidateHome();
    returning.add(const LoadHomeData());
    await _pump();
    expect(repo.calls.length, 2);
    repo.calls[1].complete(Right(_model('Ana 2')));
    await _pump();

    returning.add(const LoadHomeData(force: true));
    await _pump();
    expect(repo.calls.length, 3);
    await returning.close();
  });

  test('location change bypasses the cache', () async {
    bloc.add(const LoadHomeData());
    await _pump();
    repo.calls.single.complete(Right(_model('Ana')));
    await _pump();
    bloc.add(const LoadHomeData(latitude: -19.9, longitude: -43.9));
    await _pump();
    expect(repo.calls.length, 2);
  });

  test('failure keeps previously loaded data visible', () async {
    bloc.add(const LoadHomeData());
    await _pump();
    repo.calls.single.complete(Right(_model('Ana')));
    await _pump();
    bloc.add(const LoadHomeData(force: true));
    await _pump();
    repo.calls[1].complete(
      const Left(ServerFailure(errorCode: ErrorCode.unknown, message: 'boom')),
    );
    await _pump();
    expect(bloc.state, isA<HomeLoaded>());
  });
}
