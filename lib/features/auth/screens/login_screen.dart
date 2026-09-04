import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _codeSent = false;
  bool _loading = false;
  String _fullPhone = '';
  final _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _err(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    return 'Une erreur est survenue. Vérifiez votre connexion.';
  }

  Future<void> _sendCode() async {
    if (_fullPhone.length < 8) {
      _snack('Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().sendOtp(_fullPhone);
      setState(() => _codeSent = true);
      _snack('Code envoyé par SMS.', color: AppColors.success);
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _snack('Entrez le code à 6 chiffres.');
      return;
    }
    setState(() => _loading = true);
    try {
      final loggedIn =
          await context.read<AuthController>().verifyOtp(_fullPhone, otp);
      if (!mounted) return;
      if (loggedIn) {
        context.go('/home');
      } else {
        // Nouveau magasin -> inscription
        context.go('/register?phone=${Uri.encodeComponent(_fullPhone)}');
      }
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('VigiRoutes — Magasin',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  _codeSent
                      ? 'Entrez le code reçu par SMS'
                      : 'Connectez-vous avec votre numéro',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),

                if (!_codeSent) ...[
                  IntlPhoneField(
                    initialCountryCode: 'CI',
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (phone) => _fullPhone = phone.completeNumber,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendCode,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Recevoir le code'),
                    ),
                  ),
                ] else ...[
                  Pinput(
                    length: 6,
                    controller: _otpCtrl,
                    autofocus: true,
                    onCompleted: (_) => _verify(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _verify,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Vérifier'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _otpCtrl.clear();
                            }),
                    child: const Text('Modifier le numéro'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
