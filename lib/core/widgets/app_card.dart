import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'pressable.dart';

/// Carte de surface standard (bordure fine, coins arrondis, tactile optionnel).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.md),
    this.gradient,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.radius = Radii.lgAll,
    this.glow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color color;
  final Color borderColor;
  final BorderRadius radius;

  /// Ombre colorée subtile sous la carte.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: glow == null
            ? null
            : [
                BoxShadow(
                  color: glow!.withValues(alpha: 0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                  spreadRadius: -8,
                ),
              ],
      ),
      // Surface transparente : les effets d'encre des enfants restent visibles.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

/// Pastille carrée teintée contenant une icône.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.brand,
    this.size = 44,
    this.iconSize,
    this.filled = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.5,
        color: filled ? Colors.white : color,
      ),
    );
  }
}

/// Indicateur d'état : point lumineux + libellé.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.success,
    this.dot = true,
  });

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
