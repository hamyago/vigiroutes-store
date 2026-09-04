/// Modèle magasin — parsing tolérant (le backend peut renvoyer certains
/// nombres en chaîne selon la sérialisation).
class StoreModel {
  final String id;
  final String name;
  final String? managerName;
  final String phone;
  final String? email;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final bool isActive;
  final bool isBlocked;
  final bool hasActiveSubscription;
  final String? photoUrl;
  final String? managerPhotoUrl;
  final String? rccmUrl;
  final String? dfeUrl;
  final String? idCardFrontUrl;
  final String? idCardBackUrl;
  final int maxProducts;
  final double rating;
  final int totalOrders;

  StoreModel({
    required this.id,
    required this.name,
    this.managerName,
    required this.phone,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    required this.isVerified,
    required this.isActive,
    required this.isBlocked,
    required this.hasActiveSubscription,
    this.photoUrl,
    this.managerPhotoUrl,
    this.rccmUrl,
    this.dfeUrl,
    this.idCardFrontUrl,
    this.idCardBackUrl,
    required this.maxProducts,
    required this.rating,
    required this.totalOrders,
  });

  static bool _toBool(dynamic v) =>
      v == true || v == 1 || v == '1' || v == 'true';

  static double? _toDoubleN(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double _toDouble(dynamic v) => _toDoubleN(v) ?? 0;

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory StoreModel.fromJson(Map<String, dynamic> j) => StoreModel(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        managerName: j['manager_name']?.toString(),
        phone: j['phone']?.toString() ?? '',
        email: j['email']?.toString(),
        address: j['address']?.toString(),
        latitude: _toDoubleN(j['latitude']),
        longitude: _toDoubleN(j['longitude']),
        isVerified: _toBool(j['is_verified']),
        isActive: _toBool(j['is_active']),
        isBlocked: _toBool(j['is_blocked']),
        hasActiveSubscription: _toBool(j['has_active_subscription']),
        photoUrl: j['photo_url']?.toString(),
        managerPhotoUrl: j['manager_photo_url']?.toString(),
        rccmUrl: j['rccm_url']?.toString(),
        dfeUrl: j['dfe_url']?.toString(),
        idCardFrontUrl: j['id_card_front_url']?.toString(),
        idCardBackUrl: j['id_card_back_url']?.toString(),
        maxProducts: j['max_products'] == null ? 10 : _toInt(j['max_products']),
        rating: _toDouble(j['rating']),
        totalOrders: _toInt(j['total_orders']),
      );
}
