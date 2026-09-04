import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

/// Onglet Crédit : solde de l'abonnement + recharge Mobile Money (DigitalPaye).
/// Réutilise le flux validé : initiation -> suivi du statut -> mise à jour.
class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  bool _loading = true;
  bool _recharging = false;
  Map<String, dynamic>? _subscription;

  final List<int> _presets = const [2000, 5000, 15000];
  int _preset = 2000;
  bool _useCustom = false;
  final _customCtrl = TextEditingController();

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _operatorCode = 'ORANGE_MONEY_CI';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool get _needsOtp => _operatorCode == 'ORANGE_MONEY_CI';

  int? get _amount {
    if (_useCustom) {
      return int.tryParse(_customCtrl.text.trim().replaceAll(' ', ''));
    }
    return _preset;
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
    return 'Une erreur est survenue. Réessayez.';
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.getSubscription();
      if (mounted) setState(() => _subscription = res);
    } catch (_) {
      // On laisse l'écran s'afficher même sans abonnement.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _pollStatus(String reference) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final res =
            await ApiService.instance.getStoreRechargeStatus(reference);
        final status = res['status'] as String? ?? 'pending';
        if (status == 'success' || status == 'failed') return status;
      } catch (_) {}
    }
    return 'timeout';
  }

  Future<void> _recharge() async {
    final amount = _amount;
    if (amount == null || amount < AppConstants.minRecharge) {
      _snack('Le montant minimum est de ${AppConstants.minRecharge} F.');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) {
      _snack('Entrez le numéro Mobile Money qui effectue le paiement.');
      return;
    }
    final otp = _needsOtp ? _otpCtrl.text.trim() : null;
    if (_needsOtp && (otp == null || otp.isEmpty)) {
      _snack('Un code OTP Orange Money est requis.');
      return;
    }

    setState(() => _recharging = true);
    String? reference;
    try {
      final init = await ApiService.instance.initiateStoreRecharge(
        amount: amount,
        operatorCode: _operatorCode,
        payerPhone: phone,
        otp: otp,
      );
      reference = init['reference'] as String?;
    } catch (e) {
      setState(() => _recharging = false);
      _snack(_err(e), color: AppColors.error);
      return;
    }

    if (reference == null) {
      setState(() => _recharging = false);
      _snack('Réponse inattendue du serveur.', color: AppColors.error);
      return;
    }

    final status = await _pollStatus(reference);
    if (!mounted) return;
    setState(() => _recharging = false);

    if (status == 'success') {
      _otpCtrl.clear();
      _snack('Recharge confirmée ! Votre solde est à jour.',
          color: AppColors.success);
      await _load();
    } else if (status == 'failed') {
      _snack('Le paiement a échoué ou a été refusé.', color: AppColors.error);
    } else {
      _snack('Paiement en attente. Le solde se mettra à jour sous peu.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final sub = _subscription?['subscription'] as Map<String, dynamic>?;
    final percent = (_subscription?['credit_percent'] as num?)?.toInt() ?? 0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '18% du montant de chaque commande terminée est déduit de ce solde.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            if (sub != null) _balanceCard(sub, percent),
            const SizedBox(height: 24),

            const Text('Choisissez un montant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((p) {
                final selected = !_useCustom && _preset == p;
                return GestureDetector(
                  onTap: () => setState(() {
                    _useCustom = false;
                    _preset = p;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('$p F',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customCtrl,
              keyboardType: TextInputType.number,
              onTap: () => setState(() => _useCustom = true),
              onChanged: (_) => setState(() => _useCustom = true),
              decoration: InputDecoration(
                labelText: 'Autre montant (min. 2 000 F)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _useCustom
                          ? AppColors.primary
                          : AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Opérateur Mobile Money',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: AppConstants.operators.map((m) {
                final code = m['code'] as String;
                final selected = _operatorCode == code;
                return GestureDetector(
                  onTap: () => setState(() => _operatorCode = code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(m['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            const Text('Numéro Mobile Money',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ex : 07 00 00 00 00',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            if (_needsOtp) ...[
              const SizedBox(height: 18),
              const Text('Code OTP Orange Money',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Code reçu sur votre téléphone',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Générez le code depuis le menu Orange Money de votre téléphone.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _recharging ? null : _recharge,
                child: _recharging
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Recharger'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),

        if (_recharging)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Paiement en cours…',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text(
                        'Validez la demande sur votre téléphone si nécessaire, puis patientez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _balanceCard(Map<String, dynamic> sub, int percent) {
    final balance = _num(sub['credit_balance']);
    final initial = _num(sub['credit_initial']);
    final floor = _num(sub['credit_floor']);
    final color = percent > 50
        ? AppColors.success
        : percent > 20
            ? Colors.orange
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Solde actuel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${balance.toStringAsFixed(0)} F',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rechargé : ${initial.toStringAsFixed(0)} F',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text('Seuil : ${floor.toStringAsFixed(0)} F',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
