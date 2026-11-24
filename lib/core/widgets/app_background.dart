import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fond de marque : nuit profonde + halos lumineux discrets.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.glow = AppColors.brand,
    this.secondaryGlow = AppColors.violet,
  });

  final Widget child;
  final Color glow;
  final Color secondaryGlow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -140,
            child: _Halo(color: glow.withValues(alpha: 0.22), size: 480),
          ),
          Positioned(
            bottom: -220,
            right: -160,
            child: _Halo(
              color: secondaryGlow.withValues(alpha: 0.10),
              size: 520,
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
