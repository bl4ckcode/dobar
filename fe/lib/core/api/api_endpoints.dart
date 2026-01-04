class ApiEndpoints {
  static const String baseUrl = 'https://barz-backend-bold-sun-5691.fly.dev';

  // Auth endpoints (updated to match backend)
  static const String authPhone = '/auth/phone-login';
  static const String authGoogle = '/auth/google-login';
  static const String authApple = '/auth/apple-login';

  static const String bars = '/bars/';
  static String bar(int id) => '/bars/$id';
  static String barImage(int id) => '/bars/$id/image';
  static String refreshBarImage(int id) => '/bars/$id/refresh-image';

  // Menus
  static const String menusCreate = '/menus/';
  static String menus(int barId) => '/menus/$barId';
  static String menuItems(int menuId) => '/menus/items/$menuId';
  static String updateMenuItem(int menuId, String itemName) => '/menus/$menuId/items/$itemName';

  static const String cart = '/cart/';
  static const String cartItems = '/cart/items';
  static String cartItem(int itemId) => '/cart/items/$itemId';
  static const String cartCheckout = '/cart/checkout';

  static const String orders = '/orders/';
  static const String myOrders = '/orders/user/me';
  static String order(int id) => '/orders/$id';
  static String orderTimeline(int id) => '/orders/$id/timeline';
  static String cancelOrder(int id) => '/orders/$id/cancel';

  // Profile endpoints (updated to /me prefix)
  static const String profile = '/me/profile';
  static const String acceptTerms = '/me/accept-terms';
  static const String acceptPrivacy = '/me/accept-privacy';
  
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
  static String removeStaff(int barId, int staffId) => '/bars/$barId/staff/$staffId';
}

