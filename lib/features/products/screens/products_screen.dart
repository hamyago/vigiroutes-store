import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/auth_controller.dart';

/// Onglet Produits : liste + ajout / modification / suppression.
/// Limite = max_products du magasin (réglable par l'admin).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _loadError;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await ApiService.instance.getProducts();
      setState(() =>
          _products = list.map((e) => (e as Map).cast<String, dynamic>()).toList());
    } catch (e) {
      String msg = 'Impossible de charger les produits.';
      if (e is DioException) {
        final code = e.response?.statusCode;
        final data = e.response?.data;
        final serverMsg =
            (data is Map && data['message'] is String) ? data['message'] : null;
        msg = 'Erreur $code : ${serverMsg ?? e.message}';
      } else {
        msg = 'Erreur : $e';
      }
      setState(() => _loadError = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return 'Action impossible. Réessayez.';
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _addOrEdit({Map<String, dynamic>? product}) async {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(
        text: isEdit ? _num(product['unit_price']).toStringAsFixed(0) : '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Modifier le produit' : 'Ajouter un produit',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nom du produit',
                hintText: 'Ex : Plaquette de frein Toyota',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prix unitaire (F)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    final price = int.tryParse(priceCtrl.text.trim().replaceAll(' ', ''));
    if (name.isEmpty || price == null || price <= 0) {
      _snack('Nom et prix valides requis.');
      return;
    }

    try {
      if (isEdit) {
        await ApiService.instance.updateProduct(product['id'].toString(), {
          'name': name,
          'unit_price': price,
          'is_available': product['is_available'] ?? true,
        });
        _snack('Produit modifié.', color: AppColors.success);
      } else {
        await ApiService.instance.createProduct({
          'name': name,
          'unit_price': price,
        });
        _snack('Produit ajouté.', color: AppColors.success);
      }
      await _load();
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    }
  }

  Future<void> _toggleAvailable(Map<String, dynamic> p, bool value) async {
    try {
      await ApiService.instance.updateProduct(p['id'].toString(), {
        'name': p['name'],
        'unit_price': _num(p['unit_price']).toInt(),
        'is_available': value,
      });
      await _load();
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text(p['name']?.toString() ?? ''),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.deleteProduct(p['id'].toString());
      _snack('Produit supprimé.', color: AppColors.success);
      await _load();
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxProducts =
        context.watch<AuthController>().store?.maxProducts ?? 10;
    final count = _products.length;
    final atLimit = count >= maxProducts;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$count / $maxProducts produits',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              ElevatedButton.icon(
                onPressed: atLimit ? null : () => _addOrEdit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        if (atLimit)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Limite de $maxProducts produits atteinte. Supprimez-en un pour en ajouter, ou contactez VigiRoutes pour augmenter la limite.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _products.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Aucun produit.\nAjoutez-en un avec le bouton « Ajouter ».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _products.length,
                    itemBuilder: (_, i) => _productCard(_products[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final available = p['is_available'] == true ||
        p['is_available'] == 1 ||
        p['is_available'] == '1';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${_num(p['unit_price']).toStringAsFixed(0)} F',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Row(
                  children: [
                    Switch(
                      value: available,
                      onChanged: (v) => _toggleAvailable(p, v),
                    ),
                    Text(available ? 'Disponible' : 'Rupture',
                        style: TextStyle(
                            fontSize: 12,
                            color: available
                                ? AppColors.success
                                : AppColors.error)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => _addOrEdit(product: p),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _delete(p),
          ),
        ],
      ),
    );
  }
}
