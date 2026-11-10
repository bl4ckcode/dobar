import 'package:barz/core/session/shell_session.dart';
import 'package:barz/core/theme/theme_cubit.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/shared/data/data_sources/app_shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeModel _m() => HomeModel(
  locationMismatch: false,
  nearbyBars: const [],
  trendingDrinks: TrendingSection(mostWanted: [], hottest: []),
  activePromotions: const [],
);

void main() {
  test('home cache freshness follows location, staleness and invalidation', () {
    final s = ShellSession();
    expect(s.homeFresh(null, null), isFalse);
    s.storeHome(_m(), -19.9, -43.9);
    expect(s.homeFresh(-19.9001, -43.9001), isTrue);
    expect(s.homeFresh(-20.5, -43.9), isFalse, reason: 'moved far away');
    expect(s.homeFresh(null, null), isFalse, reason: 'location lost');
    s.invalidateHome();
    expect(s.homeFresh(-19.9, -43.9), isFalse);
  });

  test('Find route is kept as points and cleared explicitly', () {
    final f = ShellSession().find
      ..searchText = 'bar'
      ..cameraLat = -19.9
      ..cameraLng = -43.9
      ..routePoints = [
        [-19.9, -43.9],
        [-19.8, -43.8],
      ]
      ..routeDistance = '3 km';
    expect(f.hasCamera, isTrue);
    f.clearRoute();
    expect(f.routePoints, isEmpty);
    expect(f.destination, isNull);
    expect(f.searchText, 'bar', reason: 'search kept');
  });

  test('theme choice persists across cubit instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = ThemeCubit(AppSharedPrefs(prefs));
    expect(first.state, ThemeMode.light);
    first.toggleTheme();
    expect(first.state, ThemeMode.dark);
    final second = ThemeCubit(AppSharedPrefs(prefs));
    expect(second.state, ThemeMode.dark);
    second.toggleTheme();
    expect(ThemeCubit(AppSharedPrefs(prefs)).state, ThemeMode.light);
  });
}
