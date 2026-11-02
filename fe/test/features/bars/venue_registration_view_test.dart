import 'package:mocktail/mocktail.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/shared/data/data_sources/app_shared_prefs.dart';
import 'package:barz/features/bars/presentation/pages/create_bar/venue_registration_view.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'venue_draft_cubit_test.dart' show DraftFake;

class _SessionMock extends Mock implements SessionBloc {}

void main() {
  late _SessionMock session;
  late ThemeCubit theme;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    session = _SessionMock();
    when(
      () => session.refreshAndSelectVenue(42),
    ).thenAnswer((_) async => false);
    getItInjector.registerSingleton<SessionBloc>(session);
    SharedPreferences.setMockInitialValues({});
    theme = ThemeCubit(AppSharedPrefs(await SharedPreferences.getInstance()));
    getItInjector.registerSingleton<ThemeCubit>(theme);
  });
  tearDown(() async {
    await getItInjector.unregister<SessionBloc>();
    await getItInjector.unregister<ThemeCubit>();
    await theme.close();
  });
  Widget app(DraftFake repo, {double textScale = 1}) =>
      BlocBuilder<ThemeCubit, ThemeMode>(
        bloc: theme,
        builder: (_, mode) => MaterialApp(
          theme: getBarzLightTheme(),
          darkTheme: getBarzDarkTheme(),
          themeMode: mode,
          locale: const Locale('pt'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VenueRegistrationView(repository: repo),
        ),
      );
  testWidgets(
    'theme remains available and input contrast and values follow both themes',
    (tester) async {
      final repo = DraftFake();
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ativar tema escuro'), findsOneWidget);
      await tester.tap(find.text('Retomar cadastro'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(
        TextFormField,
        'Nome do estabelecimento *',
      );
      await tester.enterText(name, 'Meu Bar');
      final light = tester
          .widget<EditableText>(
            find.descendant(of: name, matching: find.byType(EditableText)),
          )
          .style
          .color!;
      await tester.tap(find.byTooltip('Ativar tema escuro'));
      await tester.pumpAndSettle();
      expect(find.text('Meu Bar'), findsOneWidget);
      final dark = tester
          .widget<EditableText>(
            find.descendant(of: name, matching: find.byType(EditableText)),
          )
          .style
          .color!;
      expect(dark.computeLuminance(), greaterThan(light.computeLuminance()));
      expect(find.byTooltip('Ativar tema claro'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mobile touch outside text input clears focus and keyboard connection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app(DraftFake()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retomar cadastro'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(
        TextFormField,
        'Nome do estabelecimento *',
      );
      await tester.tap(name);
      await tester.pump();
      expect(tester.testTextInput.isVisible, true);
      await tester.tap(find.text('Dados').last);
      await tester.pump();
      expect(tester.testTextInput.isVisible, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'narrow layout and larger text keep save and theme actions available',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: app(DraftFake(), textScale: 2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retomar cadastro'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar e sair'), findsOneWidget);
      expect(find.byTooltip('Ativar tema escuro'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'created venue automatically refreshes access and retry never finalizes again',
    (tester) async {
      final repo = DraftFake();
      repo.value = repo.copy(barId: 42);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar no estabelecimento'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Estabelecimento criado. Não foi possível atualizar seu acesso. Tente atualizar novamente.',
        ),
        findsOneWidget,
      );
      verify(() => session.refreshAndSelectVenue(42)).called(1);
      await tester.tap(find.text('Entrar no estabelecimento'));
      await tester.pumpAndSettle();
      verify(() => session.refreshAndSelectVenue(42)).called(1);
      expect(repo.finalizeCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
