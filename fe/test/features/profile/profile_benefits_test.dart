import 'dart:convert';
import 'dart:io';

import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/network/error/failures.dart';
import 'package:barz/features/home/presentation/cubit/profile_benefits_cubit.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_benefit_venues_page.dart';
import 'package:barz/features/home/presentation/pages/profile/profile_benefits_page.dart';
import 'package:barz/features/orders/domain/models/order_model.dart';
import 'package:barz/features/user/domain/models/profile_benefit.dart';
import 'package:barz/features/user/domain/usecases/user_usecase.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class Users extends Mock implements UserUsecase {}

Map<String, dynamic> fixture() =>
    jsonDecode(
          File(
            '../tools/agent_workflow/fixtures/profile-benefits.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

ProfileBenefits benefits() => ProfileBenefits.fromJson(
  Map<String, dynamic>.from(fixture()['benefits_response'] as Map),
);
BenefitVenues venues() => BenefitVenues.fromJson(
  Map<String, dynamic>.from(fixture()['venues_response'] as Map),
);

Widget host(Widget child, {required List<String> visited}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/profile/benefits/:id/venues',
        builder: (_, s) {
          visited.add('venues:${s.pathParameters['id']}');
          return const Scaffold(body: Text('venues-destination'));
        },
      ),
      GoRoute(
        path: '/bar/:id',
        builder: (_, s) {
          visited.add('bar:${s.pathParameters['id']}');
          return const Scaffold(body: Text('bar-destination'));
        },
      ),
    ],
  );
  return MaterialApp.router(
    locale: const Locale('pt'),
    theme: getBarzLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('state', () {
    test('counts only real active benefits from the loaded inventory', () async {
      final users = Users();
      when(() => users.getBenefits()).thenAnswer((_) async => Right(benefits()));
      final cubit = ProfileBenefitsCubit(users);
      addTearDown(cubit.close);
      expect(cubit.state.activeCount, isNull);
      await cubit.load();
      expect(cubit.state.status, BenefitsLoadStatus.loaded);
      expect(cubit.state.activeCount, 1);
    });

    test('failure and unauthorized never produce a count; retry recovers', () async {
      final users = Users();
      var calls = 0;
      when(() => users.getBenefits()).thenAnswer((_) async {
        calls++;
        if (calls == 1) return const Left(ServerFailure('boom', 500));
        if (calls == 2) return const Left(ServerFailure('no', 401));
        return Right(benefits());
      });
      final cubit = ProfileBenefitsCubit(users);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.status, BenefitsLoadStatus.failed);
      expect(cubit.state.activeCount, isNull);
      await cubit.load();
      expect(cubit.state.status, BenefitsLoadStatus.unauthorized);
      await cubit.load();
      expect(cubit.state.status, BenefitsLoadStatus.loaded);
    });

    test('venue cubit requests exactly the selected benefit', () async {
      final users = Users();
      when(
        () => users.getBenefitVenues('pro_coupon:2026-11'),
      ).thenAnswer((_) async => Right(venues()));
      final cubit = BenefitVenuesCubit(users, 'pro_coupon:2026-11');
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.data!.venues.single.barId, 12);
      verify(() => users.getBenefitVenues('pro_coupon:2026-11')).called(1);
      verifyNever(() => users.getBenefits());
    });
  });

  group('wire parsing', () {
    test('fixture parses units, eligibility and navigability', () {
      final data = benefits();
      final pro = data.benefits.first;
      final cash = data.benefits.last;
      expect(pro.canOpenVenues, isTrue);
      expect(pro.remaining, 4);
      expect(cash.unit, BenefitUnit.brlCents);
      expect(cash.canOpenVenues, isFalse);
      expect(cash.unavailableReason, 'zero_balance');
    });

    test('order history parses the additive venue name and tolerates absence', () {
      final base = {
        'id': 1, 'user_id': 2, 'bar_id': 3, 'status': 'pending',
        'order_type': 'pickup', 'payment_method': 'card',
        'created_at': '2026-11-01T10:00:00', 'updated_at': '2026-11-01T10:00:00',
      };
      expect(OrderModel.fromJson({...base, 'bar_name': 'Bar do Zé'}).barName, 'Bar do Zé');
      expect(OrderModel.fromJson(base).barName, isNull);
    });
  });

  group('widgets', () {
    testWidgets('loaded: active benefit opens only its own venues, unavailable does not', (tester) async {
      final users = Users();
      when(() => users.getBenefits()).thenAnswer((_) async => Right(benefits()));
      final visited = <String>[];
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) => ProfileBenefitsCubit(users)..load(),
            child: const ProfileBenefitsPage(),
          ),
          visited: visited,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cupons Dobar Pro'), findsOneWidget);
      expect(find.textContaining('4 de 5 cupons'), findsOneWidget);
      expect(find.textContaining('Saldo zerado'), findsOneWidget);
      expect(find.textContaining('R\$'), findsOneWidget); // zero balance rendered
      await tester.tap(find.text('Saldo de cashback'));
      await tester.pumpAndSettle();
      expect(visited, isEmpty);
      await tester.tap(find.text('Cupons Dobar Pro'));
      await tester.pumpAndSettle();
      expect(visited, ['venues:pro_coupon%3A2026-11'.replaceAll('%3A', ':')]);
      verifyNever(() => users.getBenefitVenues(any()));
    });

    testWidgets('empty, failure with retry, and unauthorized states', (tester) async {
      final users = Users();
      final empty = ProfileBenefits(
        benefits: [benefits().benefits.last],
        activeCount: 0,
      );
      var mode = 0;
      when(() => users.getBenefits()).thenAnswer((_) async {
        mode++;
        if (mode == 1) return const Left(NetworkFailure('offline'));
        if (mode == 2) return Right(empty);
        return const Left(ServerFailure('x', 401));
      });
      final cubit = ProfileBenefitsCubit(users);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        host(
          BlocProvider.value(value: cubit..load(), child: const ProfileBenefitsPage()),
          visited: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      await tester.tap(find.text('Tentar Novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Você não tem benefícios ativos no momento.'), findsOneWidget);
      await cubit.load();
      await tester.pumpAndSettle();
      expect(find.textContaining('sessão expirou'), findsOneWidget);
    });

    testWidgets('venue list shows conditions and opens the matching venue without redeeming', (tester) async {
      final users = Users();
      when(() => users.getBenefitVenues(any())).thenAnswer((_) async => Right(venues()));
      final visited = <String>[];
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) => BenefitVenuesCubit(users, 'pro_coupon:2026-11')..load(),
            child: const ProfileBenefitVenuesPage(),
          ),
          visited: visited,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Exclusivo para assinantes Dobar Pro'), findsOneWidget);
      expect(find.textContaining('Somente bebidas'), findsOneWidget);
      expect(find.textContaining('não usa nem aplica o benefício'), findsOneWidget);
      await tester.tap(find.text('Bar Sintético'));
      await tester.pumpAndSettle();
      expect(visited, ['bar:12']);
      verify(() => users.getBenefitVenues('pro_coupon:2026-11')).called(1);
      verifyNoMoreInteractions(users); // no redeem/apply call exists or is made
    });
  });
}
