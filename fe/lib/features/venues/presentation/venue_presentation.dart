import 'package:barz/core/design/components/bar_card.dart';

/// `1 234 m` -> "850m", "3.6km"; unknown distance -> empty (row hidden).
String formatVenueDistance(double? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '${meters.toInt()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

/// Backend classification -> single badge (Happy Hour → Cashback → Promotion
/// is resolved server side; unknown values show nothing).
BarBadge? badgeFor(String? classification) => switch (classification) {
  'happy_hour' => BarBadge.happyHour,
  'cashback' => BarBadge.cashback,
  'promotion' => BarBadge.promo,
  _ => null,
};

List<BarBadge> badgesFor(String? classification) {
  final badge = badgeFor(classification);
  return badge == null ? const [] : [badge];
}
