import 'package:flutter/material.dart';

import '../core/widgets/widgets.dart';

/// Gabarit des écrans de contenu.
///
/// - Dans la coquille à onglets : grand titre éditorial, sans bouton retour.
/// - En écran autonome (`standalone`) : bouton retour + titre.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.actions = const [],
    this.standalone = true,
    this.glow = AppColors.brand,
    this.bottomPadding,
  });

  final String title;
  final String? subtitle;
  final List<Widget> slivers;
  final List<Widget> actions;
  final bool standalone;
  final Color glow;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Espace pour la barre de navigation flottante quand on est dans la coquille.
    final bottom =
        bottomPadding ??
        (standalone ? Gap.xxl : 96 + MediaQuery.paddingOf(context).bottom);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        glow: glow,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.sm,
                  Gap.page,
                  Gap.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      if (standalone) ...[
                        GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Retour',
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: Gap.md),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: standalone
                                  ? t.headlineSmall
                                  : t.headlineMedium,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: t.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      for (final a in actions) ...[
                        const SizedBox(width: Gap.xs),
                        a,
                      ],
                    ],
                  ),
                ),
              ),
              ...slivers,
              SliverToBoxAdapter(child: SizedBox(height: bottom)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourci : padding horizontal standard autour d'un sliver.
class PageSection extends StatelessWidget {
  const PageSection({super.key, required this.child, this.bottom = Gap.xl});

  final Widget child;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, bottom),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}
