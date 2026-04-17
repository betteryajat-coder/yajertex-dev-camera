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
}
