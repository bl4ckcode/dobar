import 'package:barz/features/bars/domain/models/bar_model.dart';
import 'package:barz/features/home/domain/models/home_model.dart';

/// Lightweight, widget-independent state for the app shell tabs.
///
/// Only the selected tab is mounted, so anything a user would expect to find
/// again after switching tabs lives here instead of in widget state. Nothing
/// here holds controllers, animations or listeners.
class ShellSession {
  // ---- Home ---------------------------------------------------------------
  HomeModel? homeData;
  double? homeLatitude;
  double? homeLongitude;
  DateTime? homeFetchedAt;
  bool homeStale = false;

  // ---- Per-tab scroll offsets (tab index -> pixels) ------------------------
  final Map<int, double> scrollOffsets = {};

  // ---- Find ----------------------------------------------------------------
  FindSession find = FindSession();

  /// Cached Home data is reusable while the coordinates are unchanged
  /// (within ~110 m) and nothing marked it stale.
  bool homeFresh(double? lat, double? lng) {
    if (homeData == null || homeStale) return false;
    if (lat == null || lng == null) {
      return homeLatitude == null && homeLongitude == null;
    }
    if (homeLatitude == null || homeLongitude == null) return false;
    return (homeLatitude! - lat).abs() < 0.001 &&
        (homeLongitude! - lng).abs() < 0.001;
  }

  void storeHome(HomeModel data, double? lat, double? lng) {
    homeData = data;
    homeLatitude = lat;
    homeLongitude = lng;
    homeFetchedAt = DateTime.now();
    homeStale = false;
  }

  /// Account, benefit, notification, purchase or location changes.
  void invalidateHome() => homeStale = true;

  void clear() {
    homeData = null;
    homeLatitude = homeLongitude = null;
    homeFetchedAt = null;
    homeStale = false;
    scrollOffsets.clear();
    find = FindSession();
  }
}

class FindSession {
  String searchText = '';
  bool showListPanel = false;
  bool isListExpanded = false;
  bool isSearchExpanded = false;
  double? cameraLat;
  double? cameraLng;
  double cameraZoom = 15;
  BarModel? destination;

  /// Route as `[lat, lng]` pairs; restored without a new directions request.
  List<List<double>> routePoints = const [];
  String? routeDistance;
  String? routeDuration;

  bool get hasCamera => cameraLat != null && cameraLng != null;

  void clearRoute() {
    destination = null;
    routePoints = const [];
    routeDistance = null;
    routeDuration = null;
  }
}
