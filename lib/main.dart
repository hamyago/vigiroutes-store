import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/auth_controller.dart';
import 'shared/navigation/app_router.dart';

/// Handler des messages reçus quand l'app est en arrière-plan / fermée.
/// Doit être une fonction top-level annotée.
@pragma('vm:entry-point')
Future<void> _firebaseBgHandler(RemoteMessage message) async {
  // Le système affiche automatiquement la notification (payload 'notification').
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBgHandler);
  await NotificationService.instance.init();
  ApiService.instance.init();
  runApp(const VigiRoutesStoreApp());
}

class VigiRoutesStoreApp extends StatelessWidget {
  const VigiRoutesStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..bootstrap(),
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthController>();
          final router = buildRouter(auth);
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
