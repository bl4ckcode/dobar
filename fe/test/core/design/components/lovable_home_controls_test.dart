import 'package:barz/core/design/components/bar_card.dart';
import 'package:barz/core/design/components/category_pill.dart';
import 'package:barz/core/design/components/home_connected_header.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('pt'),
    theme: getBarzLightTheme(),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('category pill exposes its selected state and translated label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CategoryPill(
          icon: LucideIcons.wine,
          label: 'Bares',
          isSelected: true,
        ),
      ),
    );

    expect(find.text('Bares'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(CategoryPill)),
      matchesSemantics(
        label: 'Bares',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
  });

  testWidgets('venue badge uses localized Lovable badge copy', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 200,
          child: BarCard(
            name: 'Baxo Bar',
            type: 'Bares',
            distance: '3,6 km',
            rating: 4.8,
            badges: [BarBadge.promo],
          ),
        ),
      ),
    );

    expect(find.text('Promoção'), findsOneWidget);
    expect(find.byIcon(LucideIcons.tag), findsOneWidget);
  });

  testWidgets(
    'header shows two-line nearby prompt and capped notification count',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 420,
            child: HomeConnectedHeader(
              nearbyBarName: 'Bar e Restaurante do Zé — Unidade Savassi',
              unreadNotifications: 140,
              onNotificationTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Você está perto de'), findsOneWidget);
      expect(
        find.text('Bar e Restaurante do Zé — Unidade Savassi'),
        findsOneWidget,
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.byIcon(LucideIcons.map_pin), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    },
  );
}
