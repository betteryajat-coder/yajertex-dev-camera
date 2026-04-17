import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'dashboard_screen.dart';
import 'name_input_screen.dart';

/// Animated brand intro. After ~2.4s it routes to the dashboard if a
/// user name is already stored, otherwise to the name-input flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2400), _goNext);
  }

  Future<void> _goNext() async {
    final name = await _storage.getUserName();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) =>
            name == null ? const NameInputScreen() : const DashboardScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.softBackground),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 132)
                    .animate()
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1, 1),
                      duration: 650.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 36),
                Text(
                  'YajatXDev Geo',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                    letterSpacing: -0.4,
                  ),
                )
                    .animate(delay: 250.ms)
                    .slideY(begin: 0.3, end: 0, duration: 500.ms)
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  'Geo-tagged photography, elevated.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.subInk,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate(delay: 500.ms).fadeIn(duration: 600.ms),
                const SizedBox(height: 60),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    backgroundColor: AppTheme.primarySoft,
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
