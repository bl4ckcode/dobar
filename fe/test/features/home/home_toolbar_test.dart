import 'package:barz/core/design/components/home_connected_header.dart';
import 'package:barz/core/design/design_system.dart';
import 'package:barz/features/home/domain/home_toolbar.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

HomeModel _home({
  double? distance,
  int? promos,
  String? name = 'Ana',
  int venueId = 7,
}) => HomeModel(
  locationMismatch: false,
  nearbyBars: const [],
  trendingDrinks: TrendingSection(mostWanted: [], hottest: []),
  activePromotions: const [],
  displayName: name,
  promoSummary: promos == null ? null : PromoSummary(total: promos),
  nearestVenue: distance == null && venueId == 0
      ? null
      : NearestVenue(id: venueId, name: 'Baxo Bar', distanceMeters: distance),
);

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  locale: const Locale('pt'),
  theme: theme ?? getBarzLightTheme(),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('toolbar precedence', () {
    test('9.9 m opens check-in prompt', () {
      expect(
        resolveHomeToolbar(_home(distance: 9.9, promos: 3)),
        isA<NearbyVenueToolbar>(),
      );
    });
    test('exactly 10 m falls through to the promo greeting', () {
      expect(
        resolveHomeToolbar(_home(distance: 10, promos: 3)),
        isA<PromoGreetingToolbar>(),
      );
    });
    test('10.1 m falls through', () {
      expect(
        resolveHomeToolbar(_home(distance: 10.1, promos: 2)),
        isA<PromoGreetingToolbar>(),
      );
    });
    test('unknown distance never triggers the prompt', () {
      expect(
        resolveHomeToolbar(_home(distance: null, promos: 0)),
        isA<PlainGreetingToolbar>(),
      );
    });
    test('zero or unknown promo count yields a plain greeting', () {
      expect(
        resolveHomeToolbar(_home(distance: 50, promos: 0)),
        isA<PlainGreetingToolbar>(),
      );
      expect(
        resolveHomeToolbar(_home(distance: 50, promos: null)),
        isA<PlainGreetingToolbar>(),
      );
      expect(resolveHomeToolbar(null), isA<PlainGreetingToolbar>());
    });
    test('older payloads without new fields parse', () {
      final m = HomeModel.fromJson({'location_mismatch': false});
      expect(m.promoSummary, isNull);
      expect(m.nearestVenue, isNull);
      expect(resolveHomeToolbar(m), isA<PlainGreetingToolbar>());
    });
  });

  test('notification badge hidden at zero and capped at 99+', () {
    expect(notificationBadgeLabel(0), isNull);
    expect(notificationBadgeLabel(1), '1');
    expect(notificationBadgeLabel(99), '99');
    expect(notificationBadgeLabel(100), '99+');
  });

  testWidgets('notifications always shown; badge only above zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(HomeConnectedHeader(onNotificationTap: () {})),
    );
    expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.bySemanticsLabel('Notificações'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        HomeConnectedHeader(unreadNotifications: 150, onNotificationTap: () {}),
      ),
    );
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('promo greeting pluralizes in Portuguese', (tester) async {
    await tester.pumpWidget(
      _app(
        const HomeConnectedHeader(
          content: PromoGreetingToolbar(name: 'Ana', count: 1),
        ),
      ),
    );
    expect(find.text('Olá, Ana, você tem 1 promo'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        const HomeConnectedHeader(
          content: PromoGreetingToolbar(name: 'Ana', count: 4),
        ),
      ),
    );
    expect(find.text('Olá, Ana, você tem 4 promos'), findsOneWidget);
  });

  testWidgets('nearby prompt opens check-in callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        HomeConnectedHeader(
          content: const NearbyVenueToolbar(
            NearestVenue(id: 1, name: 'Baxo Bar', distanceMeters: 3),
          ),
          onNearbyTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Baxo Bar'));
    expect(taps, 1);
  });

  testWidgets('theme toggle is beside notifications and reports taps', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _app(HomeConnectedHeader(isDark: false, onToggleTheme: () => toggles++)),
    );
    expect(find.byIcon(LucideIcons.moon), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.moon));
    expect(toggles, 1);
    await tester.pumpWidget(
      _app(HomeConnectedHeader(isDark: true, onToggleTheme: () {})),
    );
    expect(find.byIcon(LucideIcons.sun), findsOneWidget);
  });

  testWidgets('large text and narrow width do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _app(
          const HomeConnectedHeader(
            content: PromoGreetingToolbar(
              name: 'Maria Fernanda de Albuquerque',
              count: 12,
            ),
            unreadNotifications: 120,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
