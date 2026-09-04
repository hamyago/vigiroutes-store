import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Client HTTP singleton pour l'app magasin.
/// Token Sanctum stocké dans SharedPreferences et injecté automatiquement.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  late final Dio _dio;
  String? _token;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  // ── Gestion du token ────────────────────────────────────────────────
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.prefStoreToken);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefStoreToken, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefStoreToken);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  // ── Helpers ─────────────────────────────────────────────────────────
  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);
  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);
  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);

  // ══════════════════════════════════════════════════════════════════════
  //  AUTH — OTP boutique
  // ══════════════════════════════════════════════════════════════════════

  /// Envoie un OTP par SMS au numéro.
  Future<void> sendOtp(String phone) async {
    await post('/auth/otp/send', data: {'phone': phone});
  }

  /// Vérifie l'OTP boutique.
  /// Retourne { token?, store?, is_new, phone? }.
  Future<Map<String, dynamic>> verifyOtpStore({
    required String phone,
    required String otp,
    String? fcmToken,
  }) async {
    final res = await post('/auth/otp/verify/store', data: {
      'phone': phone,
      'otp': otp,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Inscription mobile (après OTP vérifié). Documents en base64 (data URL).
  Future<Map<String, dynamic>> completeStoreProfile(
      Map<String, dynamic> data) async {
    final res = await post('/auth/store/complete-profile', data: data);
    return (res.data as Map).cast<String, dynamic>();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PROFIL
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getMe() async {
    final res = await get('/store/me');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await patch('/store/me', data: data);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> logout() async {
    try {
      await post('/store/logout');
    } catch (_) {}
    await clearToken();
  }

  // ══════════════════════════════════════════════════════════════════════
  //  PRODUITS
  // ══════════════════════════════════════════════════════════════════════

  Future<List<dynamic>> getProducts() async {
    final res = await get('/store/products');
    final d = res.data;
    if (d is List) return d;
    if (d is Map && d['data'] is List) return d['data'] as List;
    return const [];
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await post('/store/products', data: data);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> data) async {
    final res = await patch('/store/products/$id', data: data);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> deleteProduct(String id) async {
    await delete('/store/products/$id');
  }

  // ══════════════════════════════════════════════════════════════════════
  //  COMMANDES
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getOrders({int page = 1, String? status}) async {
    final res = await get('/store/orders', query: {
      'page': page,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> acceptOrder(String id) async =>
      await post('/store/orders/$id/accept');
  Future<void> markOrderReady(String id) async =>
      await post('/store/orders/$id/ready');
  Future<void> completeOrder(String id) async =>
      await post('/store/orders/$id/complete');
  Future<void> cancelOrder(String id) async =>
      await post('/store/orders/$id/cancel');

  // ══════════════════════════════════════════════════════════════════════
  //  CRÉDIT / RECHARGE (DigitalPaye)
  // ══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getSubscription() async {
    final res = await get('/store/subscription');
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Initie une recharge DigitalPaye (boutique).
  Future<Map<String, dynamic>> initiateStoreRecharge({
    required int amount,
    required String operatorCode,
    required String payerPhone,
    String? otp,
  }) async {
    final res = await post('/store/recharge/initiate', data: {
      'amount': amount,
      'operator_code': operatorCode,
      'payer_phone': payerPhone,
      if (otp != null && otp.isNotEmpty) 'otp': otp,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  /// Statut d'une recharge : 'pending' | 'success' | 'failed'.
  Future<Map<String, dynamic>> getStoreRechargeStatus(String reference) async {
    final res = await get('/store/recharge/$reference/status');
    return (res.data as Map).cast<String, dynamic>();
  }
}
