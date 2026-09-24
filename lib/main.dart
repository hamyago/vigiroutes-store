import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/auth_controller.dart';
import 'shared/navigation/app_router.dart';

// ── Handler background / terminated ──────────────────────────────────────
//
// Isolate séparé — affiche une notification locale pour les commandes.
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'] as String?;

  const handledTypes = {'new_order', 'order_update', 'credit_alert'};
  if (type == null || !handledTypes.contains(type)) return;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  final notification = message.notification;
  final title = notification?.title ?? _titleForType(type);
  final body  = notification?.body  ?? _bodyForType(type);

  await plugin.show(
    type.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'vigiroutes_store_default',
        'Notifications VigiRoutes',
        channelDescription: 'Nouvelles commandes et alertes crédit',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
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

// ── Entrée principale ─────────────────────────────────────────────────────

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFF8B0000),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: Text(
              'ERREUR UI:\n\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      );

  await Firebase.initializeApp();

  // ── Crashlytics ──────────────────────────────────────────────────────────
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final list = pair as List<dynamic>;
    await FirebaseCrashlytics.instance.recordError(
      list.first, list.last as StackTrace?, fatal: true,
    );
  }).sendPort);

  // ── FCM background handler ───────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);

  // ── Notifications + API ──────────────────────────────────────────────────
  await NotificationService.instance.init(navigatorKey: _navigatorKey);
  ApiService.instance.init();

  runApp(const VigiRoutesStoreApp());
}

// ─────────────────────────────────────────────────────────────────────────────

class VigiRoutesStoreApp extends StatelessWidget {
  const VigiRoutesStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..bootstrap(),
      child: Builder(
        builder: (context) {
          final auth   = context.watch<AuthController>();
          final router = buildRouter(auth, navigatorKey: _navigatorKey);
          return MaterialApp.router(
            title: 'VigiRoutes Magasin',
            debugShowCheckedModeBanner: false,
            theme: _theme(),
            routerConfig: router,
          );
        },
      ),
    );
  }

  ThemeData _theme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
