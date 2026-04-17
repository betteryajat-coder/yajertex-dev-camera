import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/image_processor.dart';
import '../services/location_service.dart';
import '../services/permissions_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'preview_screen.dart';

/// Live camera with front/back toggle, animated shutter, and inline
/// GPS + permission status. Captures then hands off to the preview.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _permissions = PermissionsService();
  final _location = LocationService();
  final _storage = StorageService();

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _activeCameraIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  late final AnimationController _shutterAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shutterAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final perms = await _permissions.requestCore();
    if (!perms.camera) {
      setState(() {
        _initializing = false;
        _error = perms.permanentlyDenied
            ? 'Camera permission permanently denied. Enable it in settings.'
            : 'Camera permission is required to continue.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'No cameras were detected on this device.';
        });
        return;
      }

      // Default to front camera per spec.
      final frontIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _activeCameraIndex = frontIdx >= 0 ? frontIdx : 0;

      await _initController(_cameras[_activeCameraIndex]);
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'Unable to open camera: $e';
      });
    }
  }

  Future<void> _initController(CameraDescription desc) async {
    final old = _controller;
    final controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'Camera failed to start: $e';
      });
      return;
    }
    await old?.dispose();
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _controller == null) return;
    setState(() => _initializing = true);
    _activeCameraIndex = (_activeCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_activeCameraIndex]);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    unawaited(_shutterAnim.forward(from: 0).then((_) => _shutterAnim.reverse()));

    try {
      final shot = await c.takePicture();
      final loc = await _location.getCurrentLocation();
      final name = (await _storage.getUserName()) ?? 'User';

      final destPath = await _storage.newPhotoPath();
      final isFront = c.description.lensDirection == CameraLensDirection.front;

      await ImageProcessor.stampGeoOverlay(
        srcPath: shot.path,
        dstPath: destPath,
        latitude: loc.latitude,
        longitude: loc.longitude,
        userName: name,
        timestamp: DateTime.now(),
        mirror: isFront,
      );

      // Clean up the camera plugin's temp file.
      try {
        await File(shot.path).delete();
      } catch (_) {}

      if (!mounted) return;

      if (!loc.ok && loc.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.error!),
            backgroundColor: AppTheme.ink,
          ),
        );
      }

      final saved = await Navigator.of(context).push<bool>(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => PreviewScreen(
            imagePath: destPath,
            latitude: loc.latitude,
            longitude: loc.longitude,
            userName: name,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildPreview()),
          // Shutter flash overlay
          IgnorePointer(
            child: FadeTransition(
              opacity: _shutterAnim,
              child: Container(color: Colors.white),
            ),
          ),
          _buildTopBar(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_error != null) return _buildError();

    final c = _controller;
    if (_initializing || c == null || !c.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final size = c.value.previewSize!;
        // previewSize is in sensor orientation (width = long side).
        final aspect = size.height / size.width;
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: box.maxWidth,
            height: box.maxWidth / aspect,
            child: CameraPreview(c),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 56),
            const SizedBox(height: 18),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _bootstrap,
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _permissions.openAppSettingsPage,
                  child: const Text('Open Settings',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _circleIcon(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                tint: Colors.black.withOpacity(0.35),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4FE08F),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GPS Stamp ON',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _circleIcon(
                icon: Icons.flip_camera_ios_rounded,
                onTap: _cameras.length > 1 ? _toggleCamera : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.55),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sideAction(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              _ShutterButton(
                loading: _capturing,
                onTap: _initializing || _error != null ? null : _capture,
              ),
              _sideAction(
                icon: Icons.cameraswitch_rounded,
                label: 'Flip',
                onTap: _cameras.length > 1 ? _toggleCamera : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          tint: Colors.black.withOpacity(0.35),
          radius: 100,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _sideAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const _ShutterButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            shape: loading ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: loading ? BorderRadius.circular(14) : null,
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      strokeWidth: 2.4,
                    ),
                  ),
                )
              : null,
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
            begin: 1.0,
            end: loading ? 1.0 : 1.03,
            duration: 1200.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}
