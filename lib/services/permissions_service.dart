import 'package:permission_handler/permission_handler.dart';

/// Centralised permission requests. Returns a combined status so the UI
/// can route the user accordingly (grant / retry / open settings).
class CombinedPermissions {
  final bool camera;
  final bool location;
  final bool permanentlyDenied;

  const CombinedPermissions({
    required this.camera,
    required this.location,
    required this.permanentlyDenied,
  });

  bool get allGranted => camera && location;
}

class PermissionsService {
  Future<CombinedPermissions> requestCore() async {
    final statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    final cam = statuses[Permission.camera] ?? PermissionStatus.denied;
    final loc = statuses[Permission.location] ?? PermissionStatus.denied;

    return CombinedPermissions(
      camera: cam.isGranted || cam.isLimited,
      location: loc.isGranted || loc.isLimited,
      permanentlyDenied:
          cam.isPermanentlyDenied || loc.isPermanentlyDenied,
    );
  }

  Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
