import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Récupère la position actuelle, en gérant permissions et service GPS.
  /// Lève une exception avec un message clair si indisponible.
  static Future<Position> current() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Activez la localisation (GPS) de votre téléphone puis réessayez.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'Permission de localisation refusée.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Permission de localisation bloquée. Activez-la dans les réglages de l\'application.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
