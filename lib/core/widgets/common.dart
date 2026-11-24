import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'pressable.dart';

/// Logo JammTech : bouclier dans un carré dégradé.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.5),
            blurRadius: size * 0.6,
            offset: Offset(0, size * 0.18),
            spreadRadius: -size * 0.12,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reflet supérieur
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size * 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(size * 0.3),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Icon(Icons.shield_rounded, size: size * 0.52, color: Colors.white),
          Icon(
            Icons.check_rounded,
            size: size * 0.26,
            color: AppColors.brandDeep,
          ),
        ],
      ),
    );
  }
}

/// Titre de section avec action optionnelle à droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: t.titleLarge)),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  action!,
                  style: t.labelLarge?.copyWith(color: AppColors.brandBright),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Libellé discret en capitales au-dessus d'un groupe de réglages.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Gap.lg, 4, Gap.xs),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// Groupe de lignes de réglages réunies dans une même carte.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 68),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Ligne de réglage : icône, titre, sous-titre, élément de fin.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.brand,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = destructive ? AppColors.danger : color;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 14),
          child: Row(
            children: [
              IconBadge(icon: icon, color: c, size: 38),
              const SizedBox(width: Gap.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.titleSmall?.copyWith(
                        color: destructive ? AppColors.danger : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.xs),
              trailing ??
                  (onTap != null
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de réglage avec interrupteur (toute la ligne est cliquable).
class SwitchSettingsTile extends StatelessWidget {
  const SwitchSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.color = AppColors.brand,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// État vide illustré.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: icon, size: 72, color: AppColors.textSecondary),
            const SizedBox(height: Gap.lg),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Gap.xs),
            Text(
              message,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Notification éphémère cohérente avec la charte.
void showAppSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color color = AppColors.success,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        action: action,
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Dialogue de confirmation standard. Renvoie `true` si l'utilisateur confirme.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Annuler',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? AppColors.danger : AppColors.brandBright,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
