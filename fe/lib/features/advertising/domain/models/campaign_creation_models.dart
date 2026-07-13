/// Multi-step campaign creation models for the new campaign workflow.
///
/// These models support the 5-step campaign creation flow:
/// 1. Goal & Name
/// 2. Budget & Distribution
/// 3. Creative & Details
/// 4. Targeting
/// 5. Review & Launch
library;

/// Campaign goal/objective types matching big-tech ad platforms.
enum CampaignGoal {
  /// "Ser Descoberto" — New bar, wants discovery
  discovery,

  /// "Atrair Mais Clientes" — Wants foot traffic
  footTraffic,

  /// "Promover Oferta Especial" — Promoting an offer
  promotion,

  /// "Presença Total" — Full presence across all placements
  fullPresence,
}

/// Available campaign placements.
enum CampaignPlacement {
  featured,
  search,
  mapPin,
  promo,
  banner,
}

/// Placement metadata for UI display.
extension CampaignPlacementMeta on CampaignPlacement {
  String get label {
    return switch (this) {
      CampaignPlacement.featured => 'Destaque',
      CampaignPlacement.search => 'Busca',
      CampaignPlacement.mapPin => 'Mapa',
      CampaignPlacement.promo => 'Promo',
      CampaignPlacement.banner => 'Banner',
    };
  }

  String get description {
    return switch (this) {
      CampaignPlacement.featured =>
        'Apareça no carrossel em destaque da tela inicial',
      CampaignPlacement.search =>
        'Apareça primeiro nos resultados de busca',
      CampaignPlacement.mapPin =>
        'Seu pin no mapa com destaque dourado',
      CampaignPlacement.promo =>
        'Impulsione promoções ou drinks específicos',
      CampaignPlacement.banner =>
        'Banner em rotação premium pelo app',
    };
  }

  String get pricingModel {
    return switch (this) {
      CampaignPlacement.featured => 'CPC / CPM',
      CampaignPlacement.search => 'CPC',
      CampaignPlacement.mapPin => 'CPM / Taxa fixa',
      CampaignPlacement.promo => 'CPC',
      CampaignPlacement.banner => 'CPM',
    };
  }

  double get minDailyBudget {
    return switch (this) {
      CampaignPlacement.featured => 40.0,
      CampaignPlacement.search => 20.0,
      CampaignPlacement.mapPin => 25.0,
      CampaignPlacement.promo => 15.0,
      CampaignPlacement.banner => 30.0,
    };
  }
}

/// Budget distribution for a single placement.
class PlacementDistribution {
  final CampaignPlacement placement;
  final double percentage;
  final double budget;

  const PlacementDistribution({
    required this.placement,
    required this.percentage,
    required this.budget,
  });

  Map<String, dynamic> toJson() => {
    'placement': placement.name,
    'percentage': percentage,
    'budget': budget,
  };

  factory PlacementDistribution.fromJson(Map<String, dynamic> json) =>
      PlacementDistribution(
        placement: CampaignPlacement.values.firstWhere(
          (p) => p.name == json['placement'],
        ),
        percentage: (json['percentage'] as num).toDouble(),
        budget: (json['budget'] as num).toDouble(),
      );
}

/// Extended targeting options for the new campaign workflow.
class CampaignTargetingExtended {
  final double radiusKm;
  final int ageMin;
  final int ageMax;
  final bool peakHoursOnly;
  final bool budgetOptimizerEnabled;

  const CampaignTargetingExtended({
    this.radiusKm = 5.0,
    this.ageMin = 18,
    this.ageMax = 65,
    this.peakHoursOnly = false,
    this.budgetOptimizerEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'radius_km': radiusKm,
    'age_range': {'min': ageMin, 'max': ageMax},
    'peak_hours_only': peakHoursOnly,
    'budget_optimizer_enabled': budgetOptimizerEnabled,
  };

  factory CampaignTargetingExtended.fromJson(Map<String, dynamic> json) =>
      CampaignTargetingExtended(
        radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 5.0,
        ageMin: (json['age_range']?['min'] as num?)?.toInt() ?? 18,
        ageMax: (json['age_range']?['max'] as num?)?.toInt() ?? 65,
        peakHoursOnly: json['peak_hours_only'] as bool? ?? false,
        budgetOptimizerEnabled:
            json['budget_optimizer_enabled'] as bool? ?? true,
      );
}

/// Extended creative for the new campaign workflow.
class CampaignCreativeExtended {
  final String? bannerUrl;
  final String tagline;
  final String ctaType;
  final int? promotedItemId;
  final bool promoteHappyHour;

  const CampaignCreativeExtended({
    this.bannerUrl,
    this.tagline = '',
    this.ctaType = 'visit_now',
    this.promotedItemId,
    this.promoteHappyHour = false,
  });

  Map<String, dynamic> toJson() => {
    if (bannerUrl != null) 'banner_url': bannerUrl,
    'tagline': tagline,
    'cta_type': ctaType,
    if (promotedItemId != null) 'promoted_item_id': promotedItemId,
    'promote_happy_hour': promoteHappyHour,
  };

  factory CampaignCreativeExtended.fromJson(Map<String, dynamic> json) =>
      CampaignCreativeExtended(
        bannerUrl: json['banner_url'] as String?,
        tagline: json['tagline'] as String? ?? '',
        ctaType: json['cta_type'] as String? ?? 'visit_now',
        promotedItemId: json['promoted_item_id'] as int?,
        promoteHappyHour: json['promote_happy_hour'] as bool? ?? false,
      );
}

/// Estimated performance for the campaign.
class EstimatedPerformance {
  final int dailyReach;
  final int estimatedClicks;
  final int estimatedImpressions;

  const EstimatedPerformance({
    this.dailyReach = 0,
    this.estimatedClicks = 0,
    this.estimatedImpressions = 0,
  });

  Map<String, dynamic> toJson() => {
    'daily_reach': dailyReach,
    'estimated_clicks': estimatedClicks,
    'estimated_impressions': estimatedImpressions,
  };

  factory EstimatedPerformance.fromJson(Map<String, dynamic> json) =>
      EstimatedPerformance(
        dailyReach: (json['daily_reach'] as num?)?.toInt() ?? 0,
        estimatedClicks: (json['estimated_clicks'] as num?)?.toInt() ?? 0,
        estimatedImpressions:
            (json['estimated_impressions'] as num?)?.toInt() ?? 0,
      );
}

/// Complete multi-step campaign creation request.
class MultiStepCampaignRequest {
  final CampaignGoal goal;
  final String name;
  final double totalBudget;
  final DateTime startDate;
  final DateTime? endDate;
  final List<PlacementDistribution> distribution;
  final bool isSmartDistribution;
  final CampaignCreativeExtended creative;
  final CampaignTargetingExtended targeting;
  final EstimatedPerformance estimatedPerformance;

  const MultiStepCampaignRequest({
    required this.goal,
    required this.name,
    required this.totalBudget,
    required this.startDate,
    this.endDate,
    required this.distribution,
    this.isSmartDistribution = false,
    this.creative = const CampaignCreativeExtended(),
    this.targeting = const CampaignTargetingExtended(),
    this.estimatedPerformance = const EstimatedPerformance(),
  });

  Map<String, dynamic> toJson() => {
    'campaign_goal': goal.name,
    'name': name,
    'total_budget': totalBudget,
    'start_date': startDate.toIso8601String(),
    if (endDate != null) 'end_date': endDate!.toIso8601String(),
    'distribution': distribution.map((d) => d.toJson()).toList(),
    'is_smart_distribution': isSmartDistribution,
    'creative': creative.toJson(),
    'targeting': targeting.toJson(),
    'estimated_performance': estimatedPerformance.toJson(),
    'status': 'draft',
  };
}

/// CTA options for campaign creatives.
class CtaOption {
  final String value;
  final String label;

  const CtaOption(this.value, this.label);

  static const List<CtaOption> options = [
    CtaOption('visit_now', 'Visite Agora'),
    CtaOption('order_now', 'Peça Já'),
    CtaOption('check_menu', 'Confira o Cardápio'),
    CtaOption('learn_more', 'Saiba Mais'),
    CtaOption('book_now', 'Reserve Agora'),
  ];
}

/// Smart budget recommendations based on campaign goal.
extension CampaignGoalSmartBudget on CampaignGoal {
  List<PlacementDistribution> smartRecommendations(double totalBudget) {
    return switch (this) {
      CampaignGoal.discovery => [
        PlacementDistribution(
          placement: CampaignPlacement.featured,
          percentage: 50,
          budget: totalBudget * 0.5,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.mapPin,
          percentage: 30,
          budget: totalBudget * 0.3,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.search,
          percentage: 20,
          budget: totalBudget * 0.2,
        ),
      ],
      CampaignGoal.footTraffic => [
        PlacementDistribution(
          placement: CampaignPlacement.search,
          percentage: 40,
          budget: totalBudget * 0.4,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.mapPin,
          percentage: 35,
          budget: totalBudget * 0.35,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.featured,
          percentage: 25,
          budget: totalBudget * 0.25,
        ),
      ],
      CampaignGoal.promotion => [
        PlacementDistribution(
          placement: CampaignPlacement.promo,
          percentage: 45,
          budget: totalBudget * 0.45,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.banner,
          percentage: 30,
          budget: totalBudget * 0.3,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.featured,
          percentage: 25,
          budget: totalBudget * 0.25,
        ),
      ],
      CampaignGoal.fullPresence => [
        PlacementDistribution(
          placement: CampaignPlacement.featured,
          percentage: 25,
          budget: totalBudget * 0.25,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.search,
          percentage: 20,
          budget: totalBudget * 0.2,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.mapPin,
          percentage: 20,
          budget: totalBudget * 0.2,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.promo,
          percentage: 20,
          budget: totalBudget * 0.2,
        ),
        PlacementDistribution(
          placement: CampaignPlacement.banner,
          percentage: 15,
          budget: totalBudget * 0.15,
        ),
      ],
    };
  }
}