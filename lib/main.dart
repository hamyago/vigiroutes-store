import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/services/api_service.dart';
import 'features/auth/auth_controller.dart';
import 'shared/navigation/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
