import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Wraps Geolocator with predictable error types so the UI can show
/// clear messages ("GPS is off", "permission denied", etc.).
class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;

  const LocationResult({this.latitude, this.longitude, this.error});

  bool get ok => error == null && latitude != null && longitude != null;
}

class LocationService {
  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          error: 'Location services are turned off. Please enable GPS.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: 'Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          error:
              'Location permanently denied. Enable it from system settings.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return LocationResult(latitude: pos.latitude, longitude: pos.longitude);
    } catch (e) {
      return LocationResult(error: 'Unable to read location: $e');
    }
  }

  /// Reverse-geocodes [lat], [lng] into a short human place name.
  /// Priority of fields (first non-empty wins):
  ///   1. name            — explicit POI / building / society
  ///   2. thoroughfare    — street
  ///   3. subLocality     — neighbourhood / area
  ///   4. locality        — city
  ///   5. subAdministrativeArea / administrativeArea — district / state
  /// Returns null if the service is unavailable or gives nothing useful.
  Future<String?> resolveLocationName(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 10));
      if (marks.isEmpty) return null;
      final p = marks.first;
      for (final candidate in <String?>[
        p.name,
        p.thoroughfare,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
      ]) {
        final v = candidate?.trim() ?? '';
        // Skip if empty or if it's just a plus-code / coordinate string.
        if (v.isEmpty) continue;
        if (_looksLikePlusCode(v)) continue;
        return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikePlusCode(String v) {
    // Plus codes look like "M8P6+H2X" — short, uppercase alnum with a '+'.
    if (!v.contains('+')) return false;
    return RegExp(r'^[0-9A-Z+]{4,12}$').hasMatch(v.replaceAll(' ', ''));
  }
}
