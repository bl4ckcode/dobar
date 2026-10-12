/// Advertising rate card models for `GET /advertising/rates`.
///
/// This endpoint is the single source of truth for the campaign wizard:
/// per-placement pricing, accepted budget types, credit buckets and the
/// bar's current advertising tier / available credits.
///
/// Source of truth: `docs/FE_BE_COMMUNICATION.md` §"ADVERTISING RATE CARD —
/// GET /advertising/rates (CANONICAL SCHEMA)".
///
/// Important contract quirks encoded here:
/// - Monetary fields (`rate`, `rate_max`, `min_daily_budget`) arrive as JSON
///   *strings* (e.g. `"25.00"`, or `"0"` when a region has no pricing row).
///   They are always parsed numerically — never cast with `as double`/`as num`.
/// - `credits_by_tier` is regional marketing allowance data (upsell copy),
///   **not** the bar's balance. `credits_available` is the real balance.
/// - `rate_max` is non-null only for `search`; it can be `"0"` (parsed to `0.0`)
///   when the region has no `region_pricing` row. Compare numerically.
library;

/// Pricing and credit metadata for a single canonical placement.
class PlacementRate {
  final String placement;
  final String campaignType;
  final String pricingModel;

  /// The regional rate for this placement, in [RateCard.currency].
  final double rate;

  /// Upper bound of the rate range. Only `search` returns a real range today;
  /// other placements are `null`. May parse to `0.0` when the region has no
  /// pricing row. Always compare numerically, never by null-ness.
  final double? rateMax;
  final String rateUnit;

  /// Credit bucket consumed when funding with credits. `null` when the
  /// placement is not credit-backed (e.g. `push_notification`).
  final String? creditBucket;
  final String? creditUnit;
  final bool creditBacked;

  /// Minimum **daily** cash budget. Cash campaigns must satisfy
  /// `placement_budget / max(days, 1) >= minDailyBudget`.
  final double minDailyBudget;

  /// Exactly the `budget_type` values `POST /advertising/campaigns` accepts
  /// for this placement. May include `"credits"` even when the balance is 0 —
  /// gate the credit option on [RateCard.spendableCredits], not on this list.
  final List<String> allowedBudgetTypes;

  const PlacementRate({
    required this.placement,
    required this.campaignType,
    required this.pricingModel,
    required this.rate,
    this.rateMax,
    required this.rateUnit,
    this.creditBucket,
    this.creditUnit,
    required this.creditBacked,
    required this.minDailyBudget,
    required this.allowedBudgetTypes,
  });

  factory PlacementRate.fromJson(String key, Map<String, dynamic> json) =>
      PlacementRate(
        placement: json['placement'] as String? ?? key,
        campaignType: json['campaign_type'] as String,
        pricingModel: json['pricing_model'] as String,
        rate: _money(json['rate']),
        rateMax: json['rate_max'] == null ? null : _money(json['rate_max']),
        rateUnit: json['rate_unit'] as String,
        creditBucket: json['credit_bucket'] as String?,
        creditUnit: json['credit_unit'] as String?,
        creditBacked: json['credit_backed'] as bool? ?? false,
        minDailyBudget: _money(json['min_daily_budget']),
        allowedBudgetTypes: (json['allowed_budget_types'] as List? ?? const [])
            .cast<String>()
            .toList(),
      );
}


/// The full rate card for the active bar.
class RateCard {
  /// Region used to price the bar (`BR`, `US`, `MX`, ...), uppercased.
  final String regionCode;

  /// ISO currency for every monetary field. Defaults to `BRL` server-side.
  final String currency;

  /// The bar's **current advertising** tier: `regular` | `master` | `vip`.
  final String tier;

  /// Always contains all six canonical placement keys, regardless of whether
  /// the bar can currently afford them. Gate by [tier] + balance.
  final Map<String, PlacementRate> placements;

  /// Fixed order: `featured_hours`, `search_clicks`, `map_hours`,
  /// `boost_impressions`.
  final List<String> creditBuckets;

  /// Regional monthly allowance per tier (`master`, `vip`). Marketing data.
  final Map<String, Map<String, int>> creditsByTier;

  /// The bar's current remaining credits — the values to display and spend.
  final Map<String, int> creditsAvailable;

  /// Server timestamp of the response, when present.
  final DateTime? generatedAt;

  const RateCard({
    required this.regionCode,
    required this.currency,
    required this.tier,
    required this.placements,
    required this.creditBuckets,
    required this.creditsByTier,
    required this.creditsAvailable,
    this.generatedAt,
  });

  factory RateCard.fromJson(Map<String, dynamic> json) {
    final rawPlacements = json['placements'] as Map? ?? const {};
    return RateCard(
      regionCode: json['region_code'] as String? ?? 'BR',
      currency: json['currency'] as String? ?? 'BRL',
      tier: json['tier'] as String? ?? 'regular',
      placements: {
        for (final e in rawPlacements.entries)
          e.key as String: PlacementRate.fromJson(
            e.key as String,
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
      creditBuckets:
          (json['credit_buckets'] as List? ?? const []).cast<String>().toList(),
      creditsByTier: (json['credits_by_tier'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k as String, Map<String, int>.from(v as Map)),
      ),
      creditsAvailable:
          Map<String, int>.from(json['credits_available'] as Map? ?? const {}),
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }

  /// Credits the bar may actually spend for a given placement.
  int spendableCredits(String placement) {
    final bucket = placements[placement]?.creditBucket;
    if (bucket == null) return 0;
    return creditsAvailable[bucket] ?? 0;
  }

  /// Budget types to offer in the UI: drops `"credits"` when the placement is
  /// not credit-backed or the matching balance is `0`.
  List<String> usableBudgetTypes(String placement) {
    final card = placements[placement];
    if (card == null) return const [];
    if (!card.creditBacked || spendableCredits(placement) == 0) {
      return card.allowedBudgetTypes.where((t) => t != 'credits').toList();
    }
    return card.allowedBudgetTypes;
  }

  /// Minimum total budget for a placement over [days], in [currency].
  double minTotalBudget(String placement, int days) =>
      (placements[placement]?.minDailyBudget ?? 0) * (days < 1 ? 1 : days);
}

/// Parses a JSON decimal field that may arrive as a `String` (`"25.00"`,
/// `"0"`) or a `num`. Never use `as double` / `as num` on these fields.
double _money(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
