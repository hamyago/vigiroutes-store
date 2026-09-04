import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/store_models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Gère la session boutique : token, magasin courant, état d'authentification.
class AuthController extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  StoreModel? store;

  bool _pushRefreshAttached = false;

  /// Au démarrage : recharge le token et récupère le profil s'il existe.
  Future<void> bootstrap() async {
    await ApiService.instance.loadToken();
    if (!ApiService.instance.hasToken) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final me = await ApiService.instance.getMe();
      store = StoreModel.fromJson(me);
      status = AuthStatus.authenticated;
      _registerPushToken();
    } catch (_) {
      await ApiService.instance.clearToken();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Envoie l'OTP au numéro.
  Future<void> sendOtp(String phone) => ApiService.instance.sendOtp(phone);

  /// Vérifie l'OTP. Retourne true si connecté, false si nouveau (à inscrire).
  Future<bool> verifyOtp(String phone, String otp) async {
    final res = await ApiService.instance.verifyOtpStore(phone: phone, otp: otp);
    if (res['is_new'] == true) {
      return false; // -> écran d'inscription
    }
    final token = res['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await ApiService.instance.setToken(token);
      if (res['store'] is Map) {
        store = StoreModel.fromJson((res['store'] as Map).cast<String, dynamic>());
      }
      status = AuthStatus.authenticated;
      _registerPushToken();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Finalise l'inscription (après OTP). data = champs + documents base64.
  Future<void> completeRegistration(Map<String, dynamic> data) async {
    final res = await ApiService.instance.completeStoreProfile(data);
    final token = res['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await ApiService.instance.setToken(token);
    }
    if (res['store'] is Map) {
      store = StoreModel.fromJson((res['store'] as Map).cast<String, dynamic>());
    }
    status = AuthStatus.authenticated;
    _registerPushToken();
    notifyListeners();
  }

  /// Met à jour le magasin courant à partir d'un JSON (ex: après édition du profil).
  void updateStore(Map<String, dynamic> json) {
    store = StoreModel.fromJson(json);
    notifyListeners();
  }

  /// Rafraîchit le profil depuis le serveur.
  Future<void> refreshMe() async {
    try {
      final me = await ApiService.instance.getMe();
      store = StoreModel.fromJson(me);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await ApiService.instance.logout();
    store = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Récupère le token FCM de l'appareil et l'enregistre côté serveur.
  /// Appelé après chaque authentification réussie.
  Future<void> _registerPushToken() async {
    try {
      final token = await NotificationService.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.instance.updateProfile({'fcm_token': token});
      }
    } catch (_) {
      // Non bloquant : l'app fonctionne même si l'enregistrement échoue.
    }

    // Ré-enregistrer automatiquement si le token change (une seule écoute).
    if (!_pushRefreshAttached) {
      _pushRefreshAttached = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        ApiService.instance
            .updateProfile({'fcm_token': t}).catchError((_) => <String, dynamic>{});
      });
    }
  }
}
