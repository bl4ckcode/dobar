import 'package:barz/features/onboarding/domain/models/onboarding_request.dart';
import 'package:barz/core/router/route_arguments.dart';
import 'package:barz/features/session/domain/models/bar_access.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:barz/core/rbac/rbac.dart';
import 'dart:io';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/locale/locale_cubit.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:barz/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:barz/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:barz/features/session/domain/models/invitation_preview.dart';
import 'package:barz/features/session/domain/models/user_session.dart';
import 'package:barz/features/session/domain/usecases/session_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/session/presentation/cubit/invitation_cubit.dart';
import 'package:barz/features/session/presentation/pages/staff_invitation_page.dart';
import 'package:barz/features/user/domain/models/user_model.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/shared/data/data_sources/app_shared_prefs.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Session extends Mock implements SessionBloc {}

class _Usecase extends Mock implements SessionUsecase {}

class _OnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late ThemeCubit theme;
  late LocaleCubit locale;
  late _Session session;
  late _Usecase usecase;
  late _OnboardingRepository onboarding;
  late SessionState ready;
  setUpAll(() async {
    if (const bool.fromEnvironment('DOBAR_CAPTURE_ENTRY')) {
      for (final family in ['Inter', 'Oswald']) {
        final data = ByteData.sublistView(
          File(
            '${Directory.current.path}/../.agent-workflow/reports/business-entry/fonts/$family.ttf',
          ).readAsBytesSync(),
        );
        for (final weight in [100, 200, 300, 400, 500, 600, 700, 800, 900]) {
          await (FontLoader(
            '${family}_$weight',
          )..addFont(Future.value(data))).load();
        }
        await (FontLoader(
          '${family}_regular',
        )..addFont(Future.value(data))).load();
        await (FontLoader(family)..addFont(Future.value(data))).load();
        if (family == 'Inter') {
          await (FontLoader('Roboto')..addFont(Future.value(data))).load();
        }
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/flutter_lucide/lucide')..addFont(
            rootBundle.load('packages/flutter_lucide/lib/fonts/lucide.ttf'),
          ))
          .load();
    }
  });
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'app_locale': 'pt'});
    final prefs = await SharedPreferences.getInstance();
    theme = ThemeCubit(AppSharedPrefs(prefs));
    locale = LocaleCubit(prefs);
    onboarding = _OnboardingRepository();
    registerFallbackValue(
      const OnboardingRequest(userType: 'business', countryCode: 'BR'),
    );
    session = _Session();
    usecase = _Usecase();
    ready = SessionState.ready(
      session: UserSession(
        user: UserModel(
          id: 1,
          userType: UserType.business,
          hasSelectedUserType: true,
          countryCode: 'BR',
          displayName: 'Ana Silva',
        ),
      ),
    );
    when(() => session.state).thenReturn(ready);
    when(() => session.stream).thenAnswer((_) => const Stream.empty());
    getItInjector.registerSingleton<SessionBloc>(session);
    getItInjector.registerSingleton<ThemeCubit>(theme);
    getItInjector.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(repository: onboarding),
    );
  });
  tearDown(() async {
    await getItInjector.reset();
    await theme.close();
    await locale.close();
  });
  Widget app(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: theme),
      BlocProvider.value(value: locale),
      BlocProvider<SessionBloc>.value(value: session),
    ],
    child: BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (_, mode) => MaterialApp(
        theme: getBarzLightTheme(),
        darkTheme: getBarzDarkTheme(),
        themeMode: mode,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );

  testWidgets(
    'saved onboarding choices stay editable across both theme transitions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(const OnboardingPage()));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUAR'), findsOneWidget);
      final context = tester.element(find.byType(OnboardingPage));
      // The actual Continue button used to interpolate inherit:true and inherit:false.
      theme.toggleTheme();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      theme.toggleTheme();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(context.mounted, true);
      final bloc = tester
          .element(find.text('CONTINUAR'))
          .read<OnboardingBloc>();
      expect(bloc.state.selectedUserType, 'business');
      expect(bloc.state.selectedCountryCode, 'BR');
      await tester.tap(find.text('CLIENTE'));
      await tester.pumpAndSettle();
      expect(bloc.state.selectedUserType, 'client');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('onboarding Back awaits sign-out before login', (tester) async {
    final logout = Completer<void>();
    when(() => session.signOut()).thenAnswer((_) => logout.future);
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('LOGIN')),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: theme),
          BlocProvider.value(value: locale),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          theme: getBarzLightTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.arrow_left));
    await tester.pump();
    verify(() => session.signOut()).called(1);
    expect(find.text('LOGIN'), findsNothing);
    logout.complete();
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  for (final business in [false, true]) {
    testWidgets(
      'saved onboarding submits ${business ? "business to drafts" : "customer to home"} after session refresh',
      (tester) async {
        final refresh = Completer<SessionState>();
        when(
          () => session.initializeForEntry(force: true),
        ).thenAnswer((_) => refresh.future);
        when(() => onboarding.completeOnboarding(any())).thenAnswer(
          (_) async => Right(
            UserModel(
              userType: business ? UserType.business : UserType.client,
              countryCode: 'BR',
              hasSelectedUserType: true,
            ),
          ),
        );
        final router = GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const OnboardingPage(),
            ),
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('CUSTOMER HOME')),
            ),
            GoRoute(
              path: '/create-bar',
              builder: (_, state) {
                expect(
                  (state.extra as CreateBarArguments).fromOnboarding,
                  true,
                );
                return const Scaffold(body: Text('EXISTING DRAFT FLOW'));
              },
            ),
          ],
        );
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: theme),
              BlocProvider.value(value: locale),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('pt'),
              theme: getBarzLightTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!business) {
          await tester.tap(find.text('CLIENTE'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('CONTINUAR'));
        await tester.tap(find.text('CONTINUAR'));
        await tester.pump();
        expect(find.text('EXISTING DRAFT FLOW'), findsNothing);
        expect(find.text('CUSTOMER HOME'), findsNothing);
        refresh.complete(ready);
        await tester.pumpAndSettle();
        expect(
          find.text(business ? 'EXISTING DRAFT FLOW' : 'CUSTOMER HOME'),
          findsOneWidget,
        );
        verify(() => session.initializeForEntry(force: true)).called(1);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      },
    );
  }

  testWidgets('manual code keyboard dismisses on outside touch', (
    tester,
  ) async {
    final cubit = InvitationCubit(
      sessionUsecase: usecase,
      sessionBloc: session,
    );
    await tester.pumpWidget(
      app(BlocProvider.value(value: cubit, child: const StaffInvitationView())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, true);
    await tester.tap(find.text('Dobar'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, false);
    await tester.pumpWidget(const SizedBox());
    await cubit.close();
  });

  for (final width in [390.0, 1200.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'invitation preview ${width.toInt()} ${dark ? "dark" : "light"}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          if (dark) theme.toggleTheme();
          final preview = InvitationPreview(
            venueName: 'Bar Teste',
            venueAddress: 'Belo Horizonte',
            role: 'cashier',
            maskedRecipient: 'a***@example.com',
            expiresAt: DateTime.utc(2030, 1, 1),
            permissions: const ['order:view', 'order:process'],
          );
          when(
            () => usecase.previewInvitation(any()),
          ).thenAnswer((_) async => Right(preview));
          final cubit = InvitationCubit(
            sessionUsecase: usecase,
            sessionBloc: session,
            isAuthenticated: () async => true,
          );
          await cubit.submitCode('CaseSensitive_Token123');
          await tester.pumpWidget(
            app(
              BlocProvider.value(
                value: cubit,
                child: const StaffInvitationView(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Ana Silva'), findsOneWidget);
          expect(find.text('Bar Teste'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('DOBAR_CAPTURE_ENTRY')) {
            await expectLater(
              find.byType(StaffInvitationView),
              matchesGoldenFile(
                Uri.file(
                  '${Directory.current.path}/../.agent-workflow/reports/business-entry/invitation-${width.toInt()}-${dark ? "dark" : "light"}.png',
                ),
              ),
            );
          }
          await tester.pumpWidget(const SizedBox());
          await cubit.close();
        },
      );
    }
  }
  for (final width in [390.0, 1200.0]) {
    for (final dark in [false, true]) {
      for (final phase in ['signed-out', 'accepted']) {
        testWidgets(
          'invitation $phase ${width.toInt()} ${dark ? "dark" : "light"}',
          (tester) async {
            tester.view.physicalSize = Size(width, 1100);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            if (dark) theme.toggleTheme();
            final preview = InvitationPreview(
              venueName: 'Bar Teste',
              role: 'cashier',
              maskedRecipient: 'a***@example.com',
              expiresAt: DateTime.utc(2030),
              permissions: const [],
            );
            final cubit = InvitationCubit(
              sessionUsecase: usecase,
              sessionBloc: session,
              isAuthenticated: () async => false,
            );
            if (phase == 'signed-out') {
              await cubit.submitCode('CaseSensitive_Token123');
            } else {
              when(() => usecase.acceptInvitation(any())).thenAnswer(
                (_) async => const Right(
                  BarAccess(
                    barId: 42,
                    barName: 'Bar Teste',
                    role: BarRole.cashier,
                    permissions: {},
                  ),
                ),
              );
              await cubit.acceptInvitation('CaseSensitive_Token123', preview);
            }
            await tester.pumpWidget(
              app(
                BlocProvider.value(
                  value: cubit,
                  child: const StaffInvitationView(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (const bool.fromEnvironment('DOBAR_CAPTURE_ENTRY')) {
              await expectLater(
                find.byType(StaffInvitationView),
                matchesGoldenFile(
                  Uri.file(
                    '${Directory.current.path}/../.agent-workflow/reports/business-entry/$phase-${width.toInt()}-${dark ? "dark" : "light"}.png',
                  ),
                ),
              );
            }
            await tester.pumpWidget(const SizedBox());
            await cubit.close();
          },
        );
      }
    }
  }
}
