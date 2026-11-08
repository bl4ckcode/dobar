import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:barz/ui/screens/profile_wireframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barz/features/home/presentation/widgets/profile_components.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget app(GoRouter router, {bool dark = false, double scale = 1}) =>
    MaterialApp.router(
      locale: const Locale('pt'),
      theme: dark ? getBarzDarkTheme() : getBarzLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    );

GoRouter routes() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const ProfileWireframe()),
    for (final path in [
      '/profile/edit',
      '/orders',
      '/profile/benefits',
      '/profile/payments',
      '/profile/settings',
      '/legal/terms',
      '/legal/privacy',
    ])
      GoRoute(
        path: path,
        builder: (_, _) => Scaffold(body: Text('destination:$path')),
      ),
  ],
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final dark in [false, true]) {
    testWidgets(
      'profile navigation works in ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        final router = routes();
        addTearDown(router.dispose);
        await tester.pumpWidget(app(router, dark: dark));
        await tester.pumpAndSettle();
        expect(find.text('Conta'), findsOneWidget);
        expect(find.text('User Name'), findsNothing);
        expect(find.byIcon(LucideIcons.flask_conical), findsNothing);
        expect(find.text('4'), findsNothing);
        for (final destination in {
          'Conta': '/profile/edit',
          'Histórico de pedidos': '/orders',
          'Cupons, cashback e recompensas': '/profile/benefits',
          'Pagamentos': '/profile/payments',
          'Configurações': '/profile/settings',
          'Termos de uso': '/legal/terms',
          'Política de privacidade': '/legal/privacy',
        }.entries) {
          await tester.ensureVisible(find.text(destination.key));
          await tester.tap(find.text(destination.key));
          await tester.pumpAndSettle();
          expect(find.text('destination:${destination.value}'), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('narrow profile supports large text and logout cancellation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = routes();
    addTearDown(router.dispose);
    await tester.pumpWidget(app(router, dark: true, scale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Deseja sair da sua conta?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'profile primary action wraps large text and supports keyboard activation',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: getBarzLightTheme(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 280,
                child: ProfilePrimaryButton(
                  label: 'Adicionar cartão de crédito',
                  onPressed: () => activated++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
