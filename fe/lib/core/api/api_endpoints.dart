class ApiEndpoints {
  static const String baseUrl = 'https://barz-backend-bold-sun-5691.fly.dev';

  // Auth endpoints
  static const String authPhone = '/auth/phone-login';
  static const String authGoogle = '/auth/google-login';
  static const String authApple = '/auth/apple-login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMfaSetup = '/auth/mfa/setup';
  static const String authMfaVerify = '/auth/mfa/verify';
  static const String authMfaChallenge = '/auth/mfa/challenge';
  static const String authRecoveryInitiate = '/auth/recovery/initiate';
  static const String authRecoveryVerify = '/auth/recovery/verify';
  static const String home = '/home';

  static const String bars = '/bars/';
  static const String barsWizard = '/bars/wizard';
  static String bar(int id) => '/bars/$id';
  static String barImage(int id) => '/bars/$id/image';
  static String refreshBarImage(int id) => '/bars/$id/refresh-image';
  static String barLocationConfig(int id) => '/bars/$id/location-config';
  static String barActivePromotions(int id) => '/bars/$id/promotions';

  // Menus
  static const String menusCreate = '/menus/';
  static const String menuExtract = '/menus/extract';
  static String menus(int barId) => '/menus/$barId';
  static String menusForBar(int barId) => '/menus/bar/$barId';
  static String menuFull(int menuId) => '/menus/$menuId/full';

  /// New endpoint structure: /menus/{menu_id}/items (replaces deprecated /menus/items/{menu_id})
  static String menuItems(int menuId) => '/menus/$menuId/items';
  static String menuItem(int menuId, int itemId) =>
      '/menus/$menuId/items/$itemId';
  static String menuItemAvailability(int menuId, int itemId) =>
      '/menus/$menuId/items/$itemId/availability';

  /// @deprecated Use menuItems(menuId) instead
  static String menuItemsLegacy(int menuId) => '/menus/items/$menuId';

  // Trending Drinks & Categories (discovery feature)
  static const String trendingDrinks = '/menus/trending/drinks';
  static const String trendingCategories = '/menus/trending/categories';

  static const String cart = '/cart/';
  static const String cartItems = '/cart/items';
  static String cartItem(int itemId) => '/cart/items/$itemId';
  static const String cartCheckout = '/cart/checkout';
  static const String cartCalculate = '/cart/calculate';
  static const String cartSync = '/cart/sync';

  static String barSpotAvailability(int barId, String spotId) =>
      '/bars/$barId/spots/$spotId/availability';

  static const String orders = '/orders/';
  static const String myOrders = '/orders/user/me';
  static const String syncOrders = '/orders/sync';
  static String order(int id) => '/orders/$id';
  static String orderTimeline(int id) => '/orders/$id/timeline';
  static String cancelOrder(int id) => '/orders/$id/cancel';

  // Profile endpoints (updated to /me prefix)
  static const String profile = '/me/profile';
  static const String acceptTerms = '/me/accept-terms';
  static const String acceptPrivacy = '/me/accept-privacy';
  static const String userDataExclusion = '/me/data';
  static const String onboarding = '/me/onboarding';
  static const String paymentGateway = '/me/payment-gateway';

  // Legacy user endpoints (for backwards compatibility)
  static const String users = '/users';
  static const String userProfile = '/me/profile';
  static const String userPreferences = '/users/me/preferences';
  static const String userDocuments = '/users/me/documents';
  static const String userAcceptTerms = '/me/accept-terms';
  static const String userAcceptPrivacy = '/me/accept-privacy';
  static const String userWallet = '/users/me/wallet';
  static const String userCashback = '/users/me/cashback';

  static const String payments = '/payments';
  static const String pixPayment = '/payments/pix';
  static const String paymentMethods = '/payments/methods';
  static const String transactions = '/transactions';
  static const String walletTopUp = '/wallet/top-up';

  // Promotions
  static const String promotions = '/promotions/';
  static String promotion(int id) => '/promotions/$id';
  static String barPromotions(int barId) => '/promotions/bar/$barId';
  static const String nearbyPromotions = '/promotions/nearby';
  static String togglePromotion(int id) => '/promotions/$id/toggle-active';

  static const String offers = '/offers';

  // RBAC / Session Management
  static const String myBars = '/me/bars';
  static const String acceptInvitation = '/me/bars/accept-invitation';

  // Staff Management
  static String barStaff(int barId) => '/bars/$barId/staff';
  static String inviteStaff(int barId) => '/bars/$barId/staff/invite';
  static String removeStaff(int barId, int staffId) =>
      '/bars/$barId/staff/$staffId';

  // Advertising & Monetization
  // Public endpoints (no auth) - ad serving
  static const String adServeFeatured = '/advertising/serve/featured';
  static const String adServeSearch = '/advertising/serve/search';
  static const String adServeMap = '/advertising/serve/map';
  static const String adTrack = '/advertising/track';
  static const String adPlans = '/advertising/plans';

  // Authenticated endpoints - campaign/subscription management
  static const String subscriptions = '/advertising/subscriptions';
  static String subscription(int barId) => '/advertising/subscriptions/$barId';
  static String cancelSubscription(int subscriptionId) =>
      '/advertising/subscriptions/$subscriptionId/cancel';
  static const String campaigns = '/advertising/campaigns';
  static String campaign(int campaignId) =>
      '/advertising/campaigns/$campaignId';
  static String pauseCampaign(int campaignId) =>
      '/advertising/campaigns/$campaignId/pause';
  static String resumeCampaign(int campaignId) =>
      '/advertising/campaigns/$campaignId/resume';
  static String campaignAnalytics(int campaignId) =>
      '/advertising/analytics/$campaignId';

  // Google Places API Proxy (secure - API key on server)
  static const String placesAutocomplete = '/api/places/autocomplete';
  static const String placesDetails = '/api/places/details';
  static const String placesDetailsParsed = '/api/places/details/parsed';

  // Dashboard & Bar Status
  static String barDashboardStats(int barId) => '/bars/$barId/dashboard/stats';
  static String barOrders(int barId) => '/bars/$barId/orders';
  static String barStatus(int barId) => '/bars/$barId/status';
  static String barStatusToggle(int barId) => '/bars/$barId/status/toggle';

  // Legal Documents
  static String legalDocument(String type, String language) =>
      '/legal/${type}_$language.md';
}
