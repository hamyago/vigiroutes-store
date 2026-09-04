class AppConstants {
  AppConstants._();

  static const String appName     = 'VigiRoutes Magasin';
  static const String companyName = 'Oyop MT';

  static const String apiBaseUrl  = 'https://api.vigiroutes.com/api';

  // Recharge crédit
  static const int minRecharge = 2000;

  // Statuts commande (part_orders)
  static const String orderPending   = 'pending';
  static const String orderAccepted  = 'accepted';
  static const String orderReady     = 'ready';
  static const String orderCompleted = 'completed';
  static const String orderCancelled = 'cancelled';

  // SharedPreferences
  static const String prefStoreToken = 'store_token';
  static const String prefFcmToken   = 'fcm_token';

  // Opérateurs Mobile Money actifs (recharge DigitalPaye)
  static const List<Map<String, dynamic>> operators = [
    {'code': 'ORANGE_MONEY_CI', 'label': 'Orange Money', 'otp': true},
    {'code': 'MTN_MONEY_CI', 'label': 'MTN MoMo', 'otp': false},
  ];
}
