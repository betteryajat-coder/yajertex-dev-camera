import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Renders the YajatXDev Geo logo SVG inside a soft shadow container.
/// Scales cleanly at any size.
class AppLogo extends StatelessWidget {
  final double size;
  final bool withShadow;

  const AppLogo({super.key, this.size = 96, this.withShadow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: size * 0.4,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: SvgPicture.asset(
          'assets/icon/icon.svg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
