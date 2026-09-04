import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Sélectionne une image (galerie ou appareil photo) et la renvoie en
/// data URL base64 (data:image/jpeg;base64,XXXX), prête pour l'API.
class FilePickerUtil {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImageAsDataUrl({required ImageSource source}) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;

    final bytes = await File(file.path).readAsBytes();
    final b64 = base64Encode(bytes);

    final ext = file.path.split('.').last.toLowerCase();
    final mime = (ext == 'png')
        ? 'image/png'
        : (ext == 'webp')
            ? 'image/webp'
            : 'image/jpeg';

    return 'data:$mime;base64,$b64';
  }
}
