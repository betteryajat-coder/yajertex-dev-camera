import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/photo_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'camera_screen.dart';
import 'photo_detail_screen.dart';

/// Gallery of captures with a floating "Open Camera" action.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _storage = StorageService();
  List<PhotoModel> _photos = [];
  String _name = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final name = await _storage.getUserName();
    final photos = await _storage.loadPhotos();
    if (!mounted) return;
    setState(() {
      _name = name ?? '';
      _photos = photos;
      _loading = false;
    });
  }

  Future<void> _openCamera() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const CameraScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: child,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _openDetail(PhotoModel photo) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PhotoDetailScreen(photo: photo)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.softBackground),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildHeader(),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                else if (_photos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onShoot: _openCamera),
                  )
                else
                  _buildGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _FabOpenCamera(onTap: _openCamera),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppLogo(size: 46),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YajerTex Dev Camera',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        _name.isEmpty ? 'Your gallery' : 'Hi, $_name',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.subInk,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_rounded,
                          color: AppTheme.primaryDeep, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_photos.length}',
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 350.ms),
            const SizedBox(height: 22),
            _SummaryCard(count: _photos.length),
            const SizedBox(height: 20),
            if (_photos.isNotEmpty)
              Row(
                children: [
                  Text(
                    'Recent captures',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Pull to refresh',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.subInk,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final photo = _photos[i];
            return _PhotoTile(
              photo: photo,
              onTap: () => _openDetail(photo),
            ).animate(delay: (40 * i).ms).fadeIn().slideY(begin: 0.08, end: 0);
          },
          childCount: _photos.length,
        ),
      ),
    );
  }
}

// ----------------------------- subviews -----------------------------

class _SummaryCard extends StatelessWidget {
  final int count;
  const _SummaryCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        gradient: AppTheme.brandGradient,
        boxShadow: AppTheme.liftShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'Capture your first moment'
                      : 'You have $count geo-tagged ${count == 1 ? "photo" : "photos"}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every photo carries precise latitude,\nlongitude and timestamp.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoModel photo;
  final VoidCallback onTap;
  const _PhotoTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(photo.timestamp);
    final time = _formatTime(photo.timestamp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Hero(
                  tag: 'photo-${photo.id}',
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primarySoft,
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppTheme.subInk),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppTheme.subInk),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.subInk,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: photo.latitude != null
                              ? AppTheme.primary
                              : AppTheme.subInk.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[t.month - 1]} ${t.day}, ${t.year}';
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onShoot;
  const _EmptyState({required this.onShoot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primarySoft,
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: AppTheme.primaryDeep,
              size: 52,
            ),
          ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 22),
          Text(
            'No photos yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the camera button to capture your first GPS-tagged photo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.subInk,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FabOpenCamera extends StatelessWidget {
  final VoidCallback onTap;
  const _FabOpenCamera({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.liftShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Open Camera',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
    );
  }
}
