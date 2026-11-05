import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/menu_reader/domain/repositories/menu_reader_repository.dart';
import 'package:barz/features/menu_reader/presentation/bloc/menu_reader_bloc.dart';
import 'package:barz/features/menu_reader/presentation/pages/menu_reader_page.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements MenuReaderRepository {}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'menu import remains usable at $width in ${dark ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bloc = MenuReaderBloc(repository: _Repository());
          await tester.pumpWidget(
            BlocProvider.value(
              value: bloc,
              child: MaterialApp(
                theme: getBarzLightTheme(),
                darkTheme: getBarzDarkTheme(),
                themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                locale: const Locale('pt'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const MenuReaderPage(barId: 1, menuId: 1),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          final url = find.text('Colar URL do Cardápio');
          await tester.ensureVisible(url);
          await tester.tap(url);
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(TextField), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(bloc.close);
        },
      );
    }
  }

  testWidgets(
    'responsive minimum never exceeds available narrow browser width',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 280,
              child: ResponsiveCenterContainer(
                applyResponsiveLayout: true,
                child: SizedBox(key: Key('content'), height: 40),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('content'))).width,
        lessThanOrEqualTo(280),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
