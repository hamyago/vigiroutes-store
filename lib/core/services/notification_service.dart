import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gère les notifications push (FCM) et leur affichage côté magasin.
///
/// Types FCM attendus :
///   - new_order       → nouvelle commande reçue
///   - order_update    → mise à jour d'une commande existante
///   - credit_alert    → alerte solde crédit faible
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vigiroutes_store_default',
    'Notifications VigiRoutes',
    description: 'Nouvelles commandes et alertes crédit',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;

    // Permissions (Android 13+ / iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Initialisation flutter_local_notifications
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Tap en arrière-plan → navigation
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Cold start depuis notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });

    // Foreground : affiche une notification locale
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ── Foreground ─────────────────────────────────────────────────────────────

  void _handleForeground(RemoteMessage message) {
    final n    = message.notification;
    final type = message.data['type'] as String?;
    final title = n?.title ?? _titleForType(type ?? '');
    final body  = n?.body  ?? _bodyForType(type ?? '');

    _showLocal(title: title, body: body, type: type ?? '');

    // Snackbar pour les commandes urgentes
    if (type == 'new_order') {
      _showSnackbar(
        body,
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () {
            final orderId = message.data['order_id'] as String?;
            if (orderId != null) _navigate('/orders/$orderId');
          },
        ),
      );
    }
  }

  // ── Tap background / cold start ────────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    final type    = message.data['type'] as String?;
    final orderId = message.data['order_id'] as String?;

    switch (type) {
      case 'new_order':
      case 'order_update':
        if (orderId != null) _navigate('/orders/$orderId');
        else _navigate('/orders');
      case 'credit_alert':
        _navigate('/credit');
      default:
        break;
    }
  }

  // ── Notification locale ────────────────────────────────────────────────────

  Future<void> _showLocal({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      await _local.show(
        type.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackbar(String text, {SnackBarAction? action}) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _navigate(String route) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    Navigator.of(context).pushNamed(route);
  }

  String _titleForType(String type) => switch (type) {
        'new_order'    => '🛒 Nouvelle commande',
        'order_update' => '📦 Mise à jour commande',
        'credit_alert' => '⚠️ Alerte crédit',
        _              => 'VigiRoutes Magasin',
      };

  String _bodyForType(String type) => switch (type) {
        'new_order'    => 'Vous avez reçu une nouvelle commande.',
        'order_update' => 'Une commande a été mise à jour.',
        'credit_alert' => 'Votre solde crédit est faible.',
        _              => 'Appuyez pour voir les détails.',
      };

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();
}
