import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/file_picker_util.dart';
import '../auth_controller.dart';

/// Inscription boutique (lot 2). Le numéro est déjà vérifié par OTP.
/// Infos + position GPS obligatoires ; les 5 documents sont facultatifs ici
/// (complétables ensuite depuis le profil), mais nécessaires pour être vérifié.
class RegisterScreen extends StatefulWidget {
  final String phone;
  const RegisterScreen({super.key, required this.phone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _locating = false;
  bool _submitting = false;

  // Documents (data URL base64) — facultatifs.
  final Map<String, String?> _docs = {
    'manager_photo': null,
    'rccm_document': null,
    'dfe_document': null,
    'id_card_front': null,
    'id_card_back': null,
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _managerCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
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
      if (d is Map) {
        if (d['errors'] is Map) {
          final all = <String>[];
          (d['errors'] as Map).forEach((_, v) {
            if (v is List) all.addAll(v.map((x) => x.toString()));
          });
          if (all.isNotEmpty) return all.join(' ');
        }
        if (d['message'] is String) return d['message'] as String;
      }
    }
    return 'Erreur lors de l\'inscription. Réessayez.';
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.current();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      _snack('Position enregistrée.', color: AppColors.success);
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
      if (dataUrl != null) setState(() => _docs[key] = dataUrl);
    } catch (e) {
      _snack('Impossible de charger le fichier.', color: AppColors.error);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      _snack('La position du magasin est obligatoire — utilisez « Ma position ».');
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'phone': widget.phone,
        'name': _nameCtrl.text.trim(),
        'manager_name': _managerCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
      };
      // Documents fournis uniquement.
      _docs.forEach((k, v) {
        if (v != null && v.isNotEmpty) data[k] = v;
      });

      await context.read<AuthController>().completeRegistration(data);
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      _snack(_err(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _latitude != null && _longitude != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Inscrire mon magasin')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Numéro vérifié
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Numéro vérifié : ${widget.phone}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _label('Nom du magasin'),
              _text(_nameCtrl, 'Pièces Auto Abidjan', required: true),
              const SizedBox(height: 16),

              _label('Nom du gérant'),
              _text(_managerCtrl, 'Kouassi Yao', required: true),
              const SizedBox(height: 16),

              _label('Adresse email'),
              _text(_emailCtrl, 'monmagasin@email.com',
                  required: true, email: true),
              const SizedBox(height: 16),

              _label('Adresse (facultatif)'),
              _text(_addressCtrl, 'Adjamé, Abidjan'),
              const SizedBox(height: 20),

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
                        const Text('Position du magasin',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          onPressed: _locating ? null : _useMyLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 18),
                          label: const Text('Ma position'),
                        ),
                      ],
                    ),
                    Text(
                      hasLocation
                          ? 'Enregistrée : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                          : 'Indispensable pour apparaître dans les recherches à proximité.',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasLocation
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Documents (facultatifs)
              const Text('Documents de vérification',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'Facultatifs ici — mais nécessaires pour que votre magasin soit vérifié. Vous pouvez les ajouter plus tard depuis votre profil.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              _docTile('manager_photo', 'Photo du gérant'),
              _docTile('rccm_document', 'RCCM'),
              _docTile('dfe_document', 'DFE'),
              _docTile('id_card_front', 'CNI — recto'),
              _docTile('id_card_back', 'CNI — verso'),

              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Inscrire mon magasin'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Retour à la connexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _text(TextEditingController c, String hint,
      {bool required = false, bool email = false}) {
    return TextFormField(
      controller: c,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
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
      validator: (v) {
        final val = (v ?? '').trim();
        if (required && val.isEmpty) return 'Champ obligatoire';
        if (email && val.isNotEmpty && !val.contains('@')) {
          return 'Email invalide';
        }
        return null;
      },
    );
  }

  Widget _docTile(String key, String label) {
    final has = _docs[key] != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _pickDoc(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: has ? AppColors.successLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: has ? AppColors.success : AppColors.border),
          ),
          child: Row(
            children: [
              Icon(has ? Icons.check_circle : Icons.upload_file_outlined,
                  size: 20,
                  color: has ? AppColors.success : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: has
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
              ),
              Text(has ? 'Modifier' : 'Ajouter',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
