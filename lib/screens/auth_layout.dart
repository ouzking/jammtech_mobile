import 'package:flutter/material.dart';

import '../core/widgets/widgets.dart';

/// Mise en page commune aux écrans d'authentification :
/// défilement sûr avec clavier, largeur max sur tablette/web, en-tête de marque.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack = false,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBack;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, 0, 0),
                    child: GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Retour',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.page + 4,
                      vertical: Gap.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leading ?? const BrandMark(size: 56),
                          const SizedBox(height: Gap.xl),
                          Text(title, style: t.headlineMedium),
                          const SizedBox(height: Gap.xs),
                          Text(
                            subtitle,
                            style: t.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: Gap.xxl),
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: Gap.xl),
                            Center(child: footer!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Pas de compte ? S'inscrire » — texte + lien.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.text,
    required this.link,
    required this.onTap,
  });

  final String text;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(Gap.xs),
        child: Text.rich(
          TextSpan(
            text: '$text ',
            style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            children: [
              TextSpan(
                text: link,
                style: t.labelLarge?.copyWith(color: AppColors.brandBright),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
