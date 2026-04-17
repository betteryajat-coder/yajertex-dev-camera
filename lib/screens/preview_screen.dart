import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/photo_model.dart';
import '../services/image_processor.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Post-capture review: rotate, retake, or save (+ add to gallery index).
/// Returns `true` via Navigator.pop when the photo was saved.
class PreviewScreen extends StatefulWidget {
  final String imagePath;
  final double? latitude;
  final double? longitude;
  final String userName;

  const PreviewScreen({
    super.key,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.userName,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _storage = StorageService();
  int _rotationQuarterTurns = 0; // visual only; baked in on save
  bool _busy = false;
  // Bump to force Image.file to reload after we rewrite the file.
  int _imgKey = 0;

  Future<void> _rotate(int delta) async {
    if (_busy) return;
    setState(() => _rotationQuarterTurns += delta);
  }

  Future<void> _retake() async {
    if (_busy) return;
    // Discard the temp capture and go back to the camera.
    try {
      final f = File(widget.imagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // Bake any pending rotation into the file on disk.
      final quarters = ((_rotationQuarterTurns % 4) + 4) % 4;
      if (quarters != 0) {
        await ImageProcessor.rotateInPlace(widget.imagePath, quarters * 90);
      }

      final photo = PhotoModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: widget.imagePath,
        latitude: widget.latitude,
        longitude: widget.longitude,
        timestamp: DateTime.now(),
        userName: widget.userName,
      );
      await _storage.addPhoto(photo);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Photo saved to your gallery',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryDeep,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.latitude?.toStringAsFixed(6) ?? 'Unavailable';
    final lon = widget.longitude?.toStringAsFixed(6) ?? 'Unavailable';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Hero(
                    tag: 'preview-${widget.imagePath}',
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        turns: _rotationQuarterTurns / 4,
                        child: Image.file(
                          File(widget.imagePath),
                          key: ValueKey(_imgKey),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildMetaRow(lat, lon),
            const SizedBox(height: 14),
            _buildActions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _busy ? null : _retake,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Text(
            'Review',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  widget.latitude != null ? 'Geo-tagged' : 'No GPS',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String lat, String lon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _miniStat('Latitude', lat),
            ),
            Container(
              width: 1,
              height: 32,
              color: Colors.white.withOpacity(0.15),
            ),
            Expanded(
              child: _miniStat('Longitude', lon),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _miniStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _ghostButton(
              icon: Icons.rotate_left_rounded,
              label: 'Rotate L',
              onTap: _busy ? null : () => _rotate(-1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ghostButton(
              icon: Icons.rotate_right_rounded,
              label: 'Rotate R',
              onTap: _busy ? null : () => _rotate(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ghostButton(
              icon: Icons.replay_rounded,
              label: 'Retake',
              onTap: _busy ? null : _retake,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.liftShadow,
                ),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Save',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
