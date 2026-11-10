import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/router/app_routes.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/presentation/bloc/location_cubit.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';
import 'package:barz/features/location/presentation/location_permission_explainer.dart';
import 'package:barz/features/venues/domain/venue_category.dart';
import 'package:barz/features/venues/domain/venue_list_item.dart';
import 'package:barz/features/venues/domain/venue_repository.dart';
import 'package:barz/features/venues/presentation/pages/category_venues_page.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _Repo implements VenueRepository {
  final queries = <VenueQuery>[];
  @override
  Future<VenuePage> fetch(VenueQuery query) async {
    queries.add(query);
    return const VenuePage(
      items: [
        VenueListItem(
          id: 7,
          name: 'Baxo Bar',
          rating: 4.5,
          primaryPromotion: 'happy_hour',
          promotionText: '2x1 até 20h',
        ),
      ],
      total: 1,
      hasMore: false,
    );
  }
}

class _MockLocation extends Mock implements LocationCubit {}

Widget _app(Widget home, {GoRouter? router}) {
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  if (router != null) {
    return MaterialApp.router(
      routerConfig: router,
      locale: const Locale('pt'),
      theme: getBarzLightTheme(),
      localizationsDelegates: delegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
  return MaterialApp(
    locale: const Locale('pt'),
    theme: getBarzLightTheme(),
    localizationsDelegates: delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

_MockLocation _location(LocationState state) {
  final c = _MockLocation();
  when(() => c.state).thenReturn(state);
  when(() => c.stream).thenAnswer((_) => const Stream<LocationState>.empty());
  when(() => c.close()).thenAnswer((_) async {});
  return c;
}

void main() {
  testWidgets(
    'category pill route opens the dedicated list (denied location)',
    (tester) async {
      final repo = _Repo();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    AppRoute.pushCategory(context, VenueCategory.clubs),
                child: const Text('clubs'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoute.category.path,
            builder: (context, state) => BlocProvider<LocationCubit>.value(
              value: _location(const LocationState()), // permission denied
              child: CategoryVenuesPage(
                category: VenueCategory.fromRouteId(
                  state.pathParameters['categoryId'],
                )!,
                repository: repo,
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(_app(const SizedBox(), router: router));
      await tester.tap(find.text('clubs'));
      await tester.pumpAndSettle();

      expect(find.text('Clubes'), findsOneWidget); // title
      expect(find.text('Baxo Bar'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('2x1 até 20h'), findsOneWidget);
      expect(find.byTooltip('Buscar'), findsOneWidget);
      expect(find.byTooltip('Filtros'), findsOneWidget);
      expect(repo.queries.single.category, 'night_club');
      expect(repo.queries.single.hasLocation, isFalse);
      expect(
        find.textContaining('país'),
        findsOneWidget,
        reason: 'no-location notice',
      );
    },
  );

  testWidgets('permission is explained in Portuguese before it is requested', (
    tester,
  ) async {
    final cubit = _location(const LocationState());
    when(() => cubit.hasPermissionNow()).thenAnswer((_) async => false);
    when(() => cubit.isPermanentlyDenied()).thenAnswer((_) async => false);
    when(() => cubit.getCurrentLocation()).thenAnswer((_) async {});

    bool? result;
    await tester.pumpWidget(
      _app(
        BlocProvider<LocationCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await LocationPermissionExplainer.ensure(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.textContaining('verificar sua presença'), findsOneWidget);
    verifyNever(() => cubit.getCurrentLocation()); // not before consent

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    verify(() => cubit.getCurrentLocation()).called(1);
    // Denied after the prompt -> Settings recovery is offered.
    expect(find.text('Abrir ajustes'), findsOneWidget);
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('declining the explanation never requests permission', (
    tester,
  ) async {
    final cubit = _location(const LocationState());
    when(() => cubit.hasPermissionNow()).thenAnswer((_) async => false);
    when(() => cubit.isPermanentlyDenied()).thenAnswer((_) async => false);
    await tester.pumpWidget(
      _app(
        BlocProvider<LocationCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => LocationPermissionExplainer.ensure(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    verifyNever(() => cubit.getCurrentLocation());
  });

  testWidgets('permanent denial offers settings recovery', (tester) async {
    final cubit = _location(const LocationState());
    when(() => cubit.hasPermissionNow()).thenAnswer((_) async => false);
    when(() => cubit.isPermanentlyDenied()).thenAnswer((_) async => true);
    when(() => cubit.openSettings()).thenAnswer((_) async {});
    await tester.pumpWidget(
      _app(
        BlocProvider<LocationCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => LocationPermissionExplainer.ensure(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
    verify(() => cubit.openSettings()).called(1);
  });

  // Silence unused import when LocationModel is not needed by a fake.
  test(
    'placeholder keeps imports honest',
    () => expect(LocationModel, isNotNull),
  );
}
