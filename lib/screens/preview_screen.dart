import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../models/photo_model.dart';
import '../services/image_processor.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Post-capture review.
///
/// Flow:
///   - Receives the *raw* capture (no overlay yet) + lat/lng + a suggested
///     society name from reverse geocoding.
///   - User can edit the society name in a text field (auto-filled).
///   - On Save: bakes any pending rotation + stamps the final overlay in one
///     pass, writes to a fresh stamped file, indexes it, and pops true.
///   - On Retake: deletes the raw file and pops false.
class PreviewScreen extends StatefulWidget {
  final String rawImagePath;
  final double? latitude;
  final double? longitude;
  final String suggestedSocietyName;
  final bool mirrorOnSave;

  const PreviewScreen({
    super.key,
    required this.rawImagePath,
    required this.latitude,
    required this.longitude,
    required this.suggestedSocietyName,
    required this.mirrorOnSave,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _storage = StorageService();
  late final TextEditingController _societyCtrl;

  int _rotationQuarterTurns = 0; // visual only; baked on save
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _societyCtrl =
        TextEditingController(text: widget.suggestedSocietyName.trim());
  }

  @override
  void dispose() {
    _societyCtrl.dispose();
    super.dispose();
  }

  void _rotate(int delta) {
    if (_busy) return;
    setState(() => _rotationQuarterTurns += delta);
  }

  Future<void> _retake() async {
    if (_busy) return;
    try {
      final f = File(widget.rawImagePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();

    try {
      final quarters = ((_rotationQuarterTurns % 4) + 4) % 4;
      if (quarters != 0) {
        await ImageProcessor.rotateInPlace(
            widget.rawImagePath, quarters * 90);
      }

      final society = _societyCtrl.text.trim();

      final stampedPath = p.join(
        (await _storage.photoDirectory()).path,
        'yajat_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await ImageProcessor.stampGeoOverlay(
        srcPath: widget.rawImagePath,
        dstPath: stampedPath,
        latitude: widget.latitude,
        longitude: widget.longitude,
        societyName: society,
        timestamp: DateTime.now(),
        // Rotation was already baked in above, so the file now has the
        // correct orientation — but the front-cam mirror was NOT yet
        // applied (we do it as part of the overlay pass so the text
        // reads correctly).
        mirror: widget.mirrorOnSave,
      );

      // Clean up the raw file now that the stamped copy exists.
      try {
        await File(widget.rawImagePath).delete();
      } catch (_) {}

      final userName = (await _storage.getUserName()) ?? '';
      final photo = PhotoModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        path: stampedPath,
        latitude: widget.latitude,
        longitude: widget.longitude,
        timestamp: DateTime.now(),
        userName: userName,
        societyName: society,
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
    final lng = widget.longitude?.toStringAsFixed(6) ?? 'Unavailable';

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      _buildImage(),
                      const SizedBox(height: 14),
                      _buildSocietyField(),
                      const SizedBox(height: 14),
                      _buildMetaRow(lat, lng),
                    ],
                  ),
                ),
              ),
              _buildActions(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          turns: _rotationQuarterTurns / 4,
          child: Transform(
            alignment: Alignment.center,
            // Visually preview the mirror-correction that will be applied
            // on save for front-camera captures.
            transform: widget.mirrorOnSave
                ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
                : Matrix4.identity(),
            child: Image.file(
              File(widget.rawImagePath),
              fit: BoxFit.cover,
            ),
          ),
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

  Widget _buildSocietyField() {
    // Solid dark background (not white-alpha over black) — avoids the
    // "whole area turns white" bug when the field receives focus and the
    // system autofill overlay was painting white-on-white.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apartment_rounded,
                  color: AppTheme.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'Society / Area',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (widget.suggestedSocietyName.isNotEmpty)
                Text(
                  'auto-filled · tap to edit',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _societyCtrl,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const <String>[],
            keyboardType: TextInputType.text,
            keyboardAppearance: Brightness.dark,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppTheme.primary,
            decoration: InputDecoration(
              hintText: 'Enter a name (e.g. Green Valley Society)',
              hintStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.35),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMetaRow(String lat, String lng) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(child: _miniStat('Latitude', lat)),
          Container(
            width: 1,
            height: 32,
            color: Colors.white.withOpacity(0.15),
          ),
          Expanded(child: _miniStat('Longitude', lng)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
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
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
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
