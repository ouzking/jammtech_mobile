import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, danger, secondary, ghost }

/// Bouton principal de l'application, avec état de chargement intégré.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final (gradient, bg, fg, border, glow) = switch (variant) {
      AppButtonVariant.primary => (
        AppColors.brandGradient,
        null,
        Colors.white,
        null,
        AppColors.brand,
      ),
      AppButtonVariant.danger => (
        AppColors.dangerGradient,
        null,
        Colors.white,
        null,
        AppColors.danger,
      ),
      AppButtonVariant.secondary => (
        null,
        AppColors.surfaceHigh,
        AppColors.textPrimary,
        AppColors.borderStrong,
        null,
      ),
      AppButtonVariant.ghost => (
        null,
        Colors.transparent,
        AppColors.textSecondary,
        null,
        null,
      ),
    };

    final enabled = onPressed != null && !loading;

    return Pressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.medium,
        height: 56,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        decoration: BoxDecoration(
          gradient: gradient,
          color: bg,
          borderRadius: Radii.mdAll,
          border: border == null ? null : Border.all(color: border),
          boxShadow: glow == null || !enabled
              ? null
              : [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -6,
                  ),
                ],
        ),
        child: Center(
          widthFactor: 1,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: fg,
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: fg),
                        const SizedBox(width: Gap.xs),
                      ],
                      Text(
                        label,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: fg),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Bouton icône rond façon « verre », pour barres d'outils et cartes.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badge = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * 0.48, color: AppColors.textPrimary),
            if (badge)
              Positioned(
                top: size * 0.24,
                right: size * 0.26,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceHigh,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
