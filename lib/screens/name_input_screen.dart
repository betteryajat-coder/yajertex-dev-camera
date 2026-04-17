import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';
import 'dashboard_screen.dart';

/// Prompts for the user's display name. Persisted locally so it can be
/// burned into the overlay of every captured photo.
class NameInputScreen extends StatefulWidget {
  const NameInputScreen({super.key});

  @override
  State<NameInputScreen> createState() => _NameInputScreenState();
}

class _NameInputScreenState extends State<NameInputScreen> {
  final _storage = StorageService();
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _storage.setUserName(_controller.text);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.softBackground),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 64),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideX(begin: -0.08, end: 0, duration: 400.ms),
                  const SizedBox(height: 36),
                  Text(
                    'Welcome aboard',
                    style: GoogleFonts.inter(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                      letterSpacing: -0.6,
                    ),
                  ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 10),
                  Text(
                    "Let's personalise your captures.\nEnter your name to continue.",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: AppTheme.subInk,
                      height: 1.5,
                    ),
                  ).animate(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 42),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextFormField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      onFieldSubmitted: (_) => _submit(),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.ink,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Please enter your name';
                        if (t.length < 2) return 'Name is too short';
                        return null;
                      },
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    loading: _saving,
                    onPressed: _saving ? null : _submit,
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.15, end: 0),
                  const Spacer(),
                  Center(
                    child: Text(
                      'Your name is stored only on this device.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.subInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
