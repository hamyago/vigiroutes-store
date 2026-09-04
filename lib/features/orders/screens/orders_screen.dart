import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

/// Onglet Commandes : commandes de pièces reçues (clients & prestataires).
/// Flux : En attente -> Acceptée -> Prête -> Terminée (ou Annulée).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _filters = [
    {'value': '', 'label': 'Toutes'},
    {'value': 'pending', 'label': 'En attente'},
    {'value': 'accepted', 'label': 'Acceptées'},
    {'value': 'ready', 'label': 'Prêtes'},
    {'value': 'completed', 'label': 'Terminées'},
    {'value': 'cancelled', 'label': 'Annulées'},
  ];

  String _status = '';
  final List<Map<String, dynamic>> _orders = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _page = 1;
    });
    try {
      final res = await ApiService.instance.getOrders(page: 1, status: _status);
      final list = (res['data'] as List?) ?? const [];
      setState(() {
        _orders
          ..clear()
          ..addAll(list.map((e) => (e as Map).cast<String, dynamic>()));
        _lastPage = (res['last_page'] as num?)?.toInt() ?? 1;
      });
    } catch (_) {
      // liste vide affichee
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _lastPage || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final res =
          await ApiService.instance.getOrders(page: next, status: _status);
      final list = (res['data'] as List?) ?? const [];
      setState(() {
        _page = next;
        _orders.addAll(list.map((e) => (e as Map).cast<String, dynamic>()));
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _act(String id, Future<void> Function(String) fn,
      String okMsg) async {
    try {
      await fn(id);
      _snack(okMsg, color: AppColors.success);
      await _loadFirst();
    } on DioException catch (e) {
      final d = e.response?.data;
      _snack(
        (d is Map && d['message'] is String)
            ? d['message'] as String
            : 'Action impossible.',
        color: AppColors.error,
      );
    } catch (_) {
      _snack('Action impossible.', color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = _status == f['value'];
              return GestureDetector(
                onTap: () {
                  setState(() => _status = f['value']!);
                  _loadFirst();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    border: Border.all(
                        color:
                            selected ? AppColors.primary : AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(f['label']!,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            selected ? Colors.white : AppColors.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      )),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadFirst,
                      child: ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text('Aucune commande.',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFirst,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _orders.length) {
                              return _page < _lastPage
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    )
                                  : const SizedBox(height: 20);
                            }
                            return _OrderCard(
                              order: _orders[i],
                              onAccept: (id) => _act(
                                  id,
                                  ApiService.instance.acceptOrder,
                                  'Commande acceptée.'),
                              onCancel: (id) => _act(
                                  id,
                                  ApiService.instance.cancelOrder,
                                  'Commande refusée.'),
                              onReady: (id) => _act(
                                  id,
                                  ApiService.instance.markOrderReady,
                                  'Commande marquée prête.'),
                              onComplete: (id) => _act(
                                  id,
                                  ApiService.instance.completeOrder,
                                  'Commande terminée.'),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function(String) onAccept;
  final Future<void> Function(String) onCancel;
  final Future<void> Function(String) onReady;
  final Future<void> Function(String) onComplete;

  const _OrderCard({
    required this.order,
    required this.onAccept,
    required this.onCancel,
    required this.onReady,
    required this.onComplete,
  });

  static const _labels = {
    'pending': 'En attente', 'accepted': 'Acceptée', 'ready': 'Prête',
    'completed': 'Terminée', 'cancelled': 'Annulée',
  };

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  String _fmt(dynamic v) => _num(v).toStringAsFixed(0);

  Color _tone(String s) {
    switch (s) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'accepted':
      case 'ready':
        return AppColors.primary;
      default:
        return Colors.orange;
    }
  }

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refuser la commande ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Refuser',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) await onCancel(id);
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final id = order['id'].toString();
    final status = order['status']?.toString() ?? 'pending';
    final orderer = (order['orderer'] as Map?)?.cast<String, dynamic>();
    final ordererType = order['orderer_type']?.toString() == 'user'
        ? 'client'
        : 'prestataire';
    final items = (order['items'] as List?) ?? const [];
    final mapsUrl = order['delivery_maps_url']?.toString();
    final address = order['delivery_address']?.toString();
    final note = order['note']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderer?['name']?.toString() ?? 'Commande',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('$ordererType · ${orderer?['phone'] ?? '—'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _tone(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_labels[status] ?? status,
                    style: TextStyle(
                        color: _tone(status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((raw) {
            final it = (raw as Map).cast<String, dynamic>();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                        '${it['quantity']} × ${it['product_name'] ?? ''}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text('${_fmt(it['subtotal'])} F',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          }),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('${_fmt(order['total_amount'])} F',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Note : $note',
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary)),
            ),
          if (address != null && address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Adresse : $address',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          if (mapsUrl != null && mapsUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => _openMaps(mapsUrl),
                child: const Text('📍 Voir le lieu de livraison',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          const SizedBox(height: 10),
          if ((orderer?['phone']?.toString() ?? '').isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _call(orderer!['phone'].toString()),
                icon: const Icon(Icons.phone, size: 18, color: AppColors.primary),
                label: Text(
                  'Appeler le $ordererType',
                  style: const TextStyle(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _actions(context, id, status),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, String id, String status) {
    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => onAccept(id),
                child: const Text('Accepter'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _confirmCancel(context, id),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Refuser',
                    style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        );
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onReady(id),
            child: const Text('Marquer prête'),
          ),
        );
      case 'ready':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => onComplete(id),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success),
            child: const Text('Marquer terminée'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
