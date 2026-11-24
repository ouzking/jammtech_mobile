import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import '../routes.dart';
import 'alerts.dart' show AlertTile, showAlertDetails;
import 'emergency_sheets.dart';
import 'main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goTab(BuildContext context, AppTab tab, String fallbackRoute) {
    final shell = MainShell.maybeOf(context);
    shell != null
        ? shell.goTo(tab)
        : Navigator.pushNamed(context, fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DemoData.alertsRevision,
      builder: (context, _, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final recent = DemoData.alerts.take(3).toList();
    final unread = DemoData.unresolvedCount > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              Gap.page,
              Gap.sm,
              Gap.page,
              110 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // En-tête
              Row(
                children: [
                  Pressable(
                    onTap: () =>
                        _goTab(context, AppTab.profile, AppRoutes.profile),
                    semanticLabel: 'Profil',
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.brandGradient,
                        border: Border.all(
                          color: AppColors.borderStrong,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        DemoData.userName
                            .split(' ')
                            .map((p) => p[0])
                            .take(2)
                            .join(),
                        style: t.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${greeting()},',
                          style: t.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          DemoData.userName.split(' ').first,
                          style: t.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Alertes',
                    badge: unread,
                    onPressed: () =>
                        _goTab(context, AppTab.alerts, AppRoutes.alerts),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),

              // Statut de protection
              _ProtectionCard(
                onTap: () =>
                    _goTab(context, AppTab.smartHome, AppRoutes.smartHome),
              ),
              const SizedBox(height: Gap.md),

              // SOS
              _SosCard(
                onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
              ),
              const SizedBox(height: Gap.xl),

              // Actions rapides
              const SectionHeader('Actions rapides'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
                childAspectRatio: 1.45,
                children: [
                  _QuickAction(
                    icon: Icons.near_me_rounded,
                    color: AppColors.success,
                    title: 'Ma position',
                    subtitle: 'Partage en direct',
                    onTap: () => _goTab(context, AppTab.map, AppRoutes.map),
                  ),
                  _QuickAction(
                    icon: Icons.call_rounded,
                    color: AppColors.danger,
                    title: 'Urgences',
                    subtitle: 'Police, pompiers…',
                    onTap: () => showEmergencyNumbersSheet(context),
                  ),
                  _QuickAction(
                    icon: Icons.video_library_rounded,
                    color: AppColors.violet,
                    title: 'Enregistrements',
                    subtitle: '${DemoData.videos.length} vidéos',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.videoHistory),
                  ),
                  _QuickAction(
                    icon: Icons.groups_rounded,
                    color: AppColors.warning,
                    title: 'Mes proches',
                    subtitle: '${DemoData.contacts.length} contacts',
                    onTap: () => showTrustedContactsSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),

              // Activité récente
              SectionHeader(
                'Activité récente',
                action: 'Tout voir',
                onAction: () =>
                    _goTab(context, AppTab.alerts, AppRoutes.alerts),
              ),
              for (final a in recent) ...[
                AlertTile(alert: a, onTap: () => showAlertDetails(context, a)),
                const SizedBox(height: Gap.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      radius: Radii.xlAll,
      glow: AppColors.brand,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B4FE0), Color(0xFF1A2F8F), Color(0xFF101C55)],
      ),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusPill(label: 'Protection active'),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tout est sous\ncontrôle',
                      style: t.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Maison armée · 4 caméras en ligne',
                      style: t.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.verified_user_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: Radii.mdAll,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(value: '4/4', label: 'Caméras'),
                _MetricDivider(),
                _Metric(value: '3', label: 'Proches'),
                _MetricDivider(),
                _Metric(value: 'GPS', label: 'Actif'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: t.titleMedium?.copyWith(color: Colors.white)),
        Text(
          label,
          style: t.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.12),
  );
}

class _SosCard extends StatefulWidget {
  const _SosCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<_SosCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(Gap.lg),
      radius: Radii.xlAll,
      color: AppColors.surface,
      borderColor: AppColors.danger.withValues(alpha: 0.25),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'URGENCE',
                  style: t.labelSmall?.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 6),
                Text('Besoin d’aide ?', style: t.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Alertez vos proches et partagez votre position en un geste.',
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          SizedBox(
            width: 96,
            height: 96,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final offset in [0.0, 0.5])
                    Builder(
                      builder: (_) {
                        final v = (_pulse.value + offset) % 1;
                        return Container(
                          width: 64 + 32 * v,
                          height: 64 + 32 * v,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.danger.withValues(
                              alpha: 0.25 * (1 - v),
                            ),
                          ),
                        );
                      },
                    ),
                  child!,
                ],
              ),
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.dangerGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'SOS',
                  style: t.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconBadge(icon: icon, color: color, size: 40),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
