import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/file_picker_util.dart';
import '../../auth/auth_controller.dart';

/// Onglet Profil : infos boutique modifiables + position + documents KYC
/// (complétables/remplaçables) + statut de vérification. PATCH /store/me.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _locating = false;
  bool _saving = false;
  bool _initialized = false;

  // Nouveaux documents choisis (base64), envoyés seulement s'ils changent.
  // Clés API : manager_photo, rccm_document, dfe_document, id_card_front, id_card_back
  final Map<String, String?> _newDocs = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _initFrom(store) {
    _nameCtrl.text = store.name;
    _managerCtrl.text = store.managerName ?? '';
    _addressCtrl.text = store.address ?? '';
    _latitude = store.latitude;
    _longitude = store.longitude;
    _initialized = true;
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
    return 'Erreur lors de l\'enregistrement. Réessayez.';
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.current();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      _snack('Position mise à jour.', color: AppColors.success);
    } catch (e) {
      _snack(e.toString(), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickDoc(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final dataUrl = await FilePickerUtil.pickImageAsDataUrl(source: source);
      if (dataUrl != null) setState(() => _newDocs[key] = dataUrl);
    } catch (_) {
      _snack('Impossible de charger le fichier.', color: AppColors.error);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Le nom du magasin est obligatoire.');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'manager_name': _managerCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      };
      _newDocs.forEach((k, v) {
        if (v != null && v.isNotEmpty) data[k] = v;
      });

      final updated = await ApiService.instance.updateProfile(data);
      if (!mounted) return;
      context.read<AuthController>().updateStore(updated);
      _newDocs.clear();
      _snack('Profil mis à jour avec succès.', color: AppColors.success);
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthController>().store;
    if (store == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_initialized) _initFrom(store);

    final hasLocation = _latitude != null && _longitude != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // En-tête : photo gérant + nom + badge vérification
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: (store.managerPhotoUrl != null &&
                      store.managerPhotoUrl!.isNotEmpty)
                  ? NetworkImage(store.managerPhotoUrl!)
                  : null,
              child: (store.managerPhotoUrl == null ||
                      store.managerPhotoUrl!.isEmpty)
                  ? Text(
                      store.name.isNotEmpty
                          ? store.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _verifBadge(store.isVerified),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _label('Nom du magasin'),
        _text(_nameCtrl),
        const SizedBox(height: 14),

        _label('Nom du gérant'),
        _text(_managerCtrl),
        const SizedBox(height: 14),

        _label('Adresse'),
        _text(_addressCtrl),
        const SizedBox(height: 14),

        // Position
        Container(
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
                  const Text('Position',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Ma position'),
                  ),
                ],
              ),
              Text(
                hasLocation
                    ? '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                    : 'Non définie',
                style: TextStyle(
                    fontSize: 12,
                    color: hasLocation
                        ? AppColors.textSecondary
                        : AppColors.error),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Documents
        const Text('Documents de vérification',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        _docTile('manager_photo', 'Photo du gérant', store.managerPhotoUrl),
        _docTile('rccm_document', 'RCCM', store.rccmUrl),
        _docTile('dfe_document', 'DFE', store.dfeUrl),
        _docTile('id_card_front', 'CNI — recto', store.idCardFrontUrl),
        _docTile('id_card_back', 'CNI — verso', store.idCardBackUrl),

        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enregistrer'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => context.read<AuthController>().logout(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Se déconnecter',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _verifBadge(bool verified) {
    final color = verified ? AppColors.success : AppColors.warning;
    final bg = verified ? AppColors.successLight : AppColors.warningLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        verified ? '✓ Vérifié' : '⏳ En attente de vérification',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _text(TextEditingController c) => TextField(
        controller: c,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      );

  Widget _docTile(String key, String label, String? currentUrl) {
    final picked = _newDocs[key] != null;
    final hasExisting = currentUrl != null && currentUrl.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: picked ? AppColors.successLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: picked ? AppColors.success : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              picked
                  ? Icons.check_circle
                  : (hasExisting
                      ? Icons.description_outlined
                      : Icons.upload_file_outlined),
              size: 20,
              color: picked
                  ? AppColors.success
                  : (hasExisting
                      ? AppColors.textSecondary
                      : AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (hasExisting && !picked)
                    GestureDetector(
                      onTap: () => _openUrl(currentUrl),
                      child: const Text('Voir le document actuel',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.primary)),
                    )
                  else if (picked)
                    const Text('Nouveau document prêt',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.success))
                  else
                    const Text('Non fourni',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _pickDoc(key),
              child: Text(hasExisting || picked ? 'Remplacer' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
