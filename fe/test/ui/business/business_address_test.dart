import 'package:barz/core/design/design_system.dart';
import 'package:barz/core/utils/injections.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_bloc.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_state.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/ui/business/forms/business_details_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class _SettingsMock extends Mock implements BusinessSettingsBloc {}

class _SessionMock extends Mock implements SessionBloc {}

void main() {
  for (final size in [const Size(1280, 900)]) {
    for (final dark in [false, true]) {
      testWidgets('address offers optional map at $size dark=$dark', (
        tester,
      ) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = _SettingsMock();
        when(() => settings.state).thenReturn(const BusinessSettingsState());
        when(
          () => settings.stream,
        ).thenAnswer((_) => const Stream<BusinessSettingsState>.empty());
        getItInjector.registerSingleton<BusinessSettingsBloc>(settings);
        addTearDown(() => getItInjector.unregister<BusinessSettingsBloc>());
        final session = _SessionMock();
        when(() => session.state).thenReturn(const SessionState.initial());
        when(
          () => session.stream,
        ).thenAnswer((_) => const Stream<SessionState>.empty());
        await tester.pumpWidget(
          BlocProvider<SessionBloc>.value(
            value: session,
            child: MaterialApp(
              theme: dark ? getBarzDarkTheme() : getBarzLightTheme(),
              locale: const Locale('pt'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: BusinessDetailsForm()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(BusinessDetailsForm)),
        )!;
        final pin = find.widgetWithText(TextButton, l10n.details_pin_on_map);
        await tester.scrollUntilVisible(
          pin,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('LAT '), findsNothing);
        expect(find.textContaining('LNG '), findsNothing);
        expect(find.text(l10n.address.toUpperCase()), findsOneWidget);
        await tester.tap(pin);
        await tester.pumpAndSettle();
        expect(find.text(l10n.details_map_coming_soon), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
