import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../app_page.dart';
import '../emergency_sheets.dart';

const _faq = [
  (
    'Comment fonctionne le bouton SOS ?',
    'Maintenez le bouton SOS pendant 3 secondes. Un compte à rebours de '
        '5 secondes vous permet d’annuler en cas d’erreur. Ensuite, vos '
        'contacts de confiance reçoivent une alerte avec votre position en direct.',
  ),
  (
    'Qui reçoit mes alertes ?',
    'Uniquement les contacts de confiance que vous avez choisis dans votre '
        'profil. JammTech ne partage jamais votre position sans votre action.',
  ),
  (
    'Puis-je utiliser JammTech sans connexion Internet ?',
    'Les appels d’urgence fonctionnent sans Internet. L’envoi de la position '
        'et des vidéos nécessite une connexion mobile ou Wi-Fi.',
  ),
  (
    'Combien de temps mes vidéos sont-elles conservées ?',
    'Les enregistrements sont conservés 30 jours, puis supprimés '
        'automatiquement. Vous pouvez les supprimer à tout moment.',
  ),
  (
    'Qu’est-ce que le code de contrainte ?',
    'Un code secret à utiliser si l’on vous force à désarmer le système : '
        'l’alarme semble désactivée, mais une alerte silencieuse est envoyée '
        'à vos proches.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Aide',
      glow: AppColors.info,
      slivers: [
        PageSection(
          child: Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: AppColors.brand,
                  title: 'Discuter',
                  subtitle: 'Réponse en ~5 min',
                  onTap: () => showAppSnack(
                    context,
                    'La messagerie arrive bientôt.',
                    icon: Icons.schedule_rounded,
                    color: AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _ContactCard(
                  icon: Icons.sos_rounded,
                  color: AppColors.danger,
                  title: 'Urgences',
                  subtitle: 'Police, SAMU…',
                  onTap: () => showEmergencyNumbersSheet(context),
                ),
              ),
            ],
          ),
        ),
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Questions fréquentes'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: Column(
                    children: [
                      for (var i = 0; i < _faq.length; i++) ...[
                        if (i > 0)
                          const Divider(indent: Gap.md, endIndent: Gap.md),
                        ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            Gap.md,
                            0,
                            Gap.md,
                            Gap.md,
                          ),
                          iconColor: AppColors.brandBright,
                          collapsedIconColor: AppColors.textTertiary,
                          expandedAlignment: Alignment.centerLeft,
                          title: Text(_faq[i].$1, style: t.titleSmall),
                          children: [
                            Text(
                              _faq[i].$2,
                              style: t.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(height: Gap.md),
          Text(title, style: t.titleSmall),
          Text(
            subtitle,
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
