class ApiEndpoints {
  static const String baseUrl = 'https://barz-backend-bold-sun-5691.fly.dev';

  static const String authPhone = '/auth/phone';
  static const String authGoogle = '/auth/google';
  static const String authApple = '/auth/apple';
  static const String authFacebook = '/auth/facebook';

  static const String bars = '/bars/';
  static String bar(int id) => '/bars/$id';

  static String menus(int barId) => '/menus/$barId';
  static String menuItems(int menuId) => '/menus/items/$menuId';

  static const String cart = '/cart/';
  static const String cartItems = '/cart/items';
  static String cartItem(int itemId) => '/cart/items/$itemId';
  static const String cartCheckout = '/cart/checkout';

  static const String orders = '/orders/';
  static const String myOrders = '/orders/user/me';
  static String order(int id) => '/orders/$id';
  static String orderTimeline(int id) => '/orders/$id/timeline';
  static String cancelOrder(int id) => '/orders/$id/cancel';

  static const String users = '/users';
  static const String userProfile = '/users/me';
  static const String userPreferences = '/users/me/preferences';
  static const String userDocuments = '/users/me/documents';
  static const String userAcceptTerms = '/users/me/accept-terms';
  static const String userAcceptPrivacy = '/users/me/accept-privacy';
  static const String userWallet = '/users/me/wallet';
  static const String userCashback = '/users/me/cashback';

  static const String payments = '/payments';
  static const String pixPayment = '/payments/pix';
  static const String paymentMethods = '/payments/methods';
  static const String transactions = '/transactions';
  static const String walletTopUp = '/wallet/top-up';

  static const String promotions = '/promotions';
  static const String offers = '/offers';
}

