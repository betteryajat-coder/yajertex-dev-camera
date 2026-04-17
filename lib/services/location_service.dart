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
  /// Prefers neighbourhood/area names over the raw `name` field — which,
  /// on many Android devices, returns the house number ("no:17", "#42").
  Future<String?> resolveLocationName(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 10));
      if (marks.isEmpty) return null;
      final p = marks.first;
      for (final candidate in <String?>[
        p.subLocality,
        p.locality,
        p.thoroughfare,
        p.subAdministrativeArea,
        p.administrativeArea,
        p.name,
      ]) {
        final v = candidate?.trim() ?? '';
        if (_isUsefulName(v)) return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Rejects empty, too-short, plus-code, and house-number-ish strings
  /// like "17", "no:17", "no.17", "#17", "flat 4b" that reverse geocoders
  /// sometimes drop into the `name` field.
  bool _isUsefulName(String v) {
    if (v.isEmpty) return false;
    if (v.length < 3) return false;
    if (_looksLikePlusCode(v)) return false;

    final lower = v.toLowerCase().trim();

    // Purely numeric.
    if (RegExp(r'^[0-9]+$').hasMatch(lower)) return false;

    // "no:17", "no.17", "no 17", "#17", "flat 17", "h.no 17", "door 3b"
    if (RegExp(
            r'^(no\.?|no:|#|h\.?no\.?|house|flat|door|apt\.?|plot)[\s:.\-]*[0-9a-z/\- ]+$')
        .hasMatch(lower)) {
      return false;
    }

    // Mostly digits (e.g. "17A", "17/5B") — not a meaningful area name.
    final digitCount = RegExp(r'[0-9]').allMatches(lower).length;
    if (digitCount > 0 && digitCount >= (lower.length / 2)) return false;

    return true;
  }

  bool _looksLikePlusCode(String v) {
    if (!v.contains('+')) return false;
    return RegExp(r'^[0-9A-Z+]{4,12}$').hasMatch(v.replaceAll(' ', ''));
  }
}
