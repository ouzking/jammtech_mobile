import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/models.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/alerts_repository.dart';
import '../data/repositories/transport_repository.dart';
import '../routes.dart';
import '../services/inbox_service.dart';
import '../services/session.dart';
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

  Future<void> _refresh(BuildContext context) async {
    try {
      await Session.refreshAll();
    } catch (e) {
      if (context.mounted) {
        showAppSnack(
          context,
          e.toString(),
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AccountRepository.instance.dashboard,
      builder: (context, dashboard, _) => ValueListenableBuilder(
        valueListenable: AlertsRepository.instance.alerts,
        builder: (context, alerts, _) =>
            _buildContent(context, dashboard, alerts),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Dashboard? d,
    List<SecurityAlert> alerts,
  ) {
    final t = Theme.of(context).textTheme;
    final recent = alerts.take(3).toList();
    final unread = alerts.any((a) => !a.resolved);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            color: AppColors.brandBright,
            backgroundColor: AppColors.surfaceHigh,
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
                      child: UserAvatar(dashboard: d, size: 48),
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
                          d == null
                              ? const _Skeleton(width: 110, height: 22)
                              : Text(d.firstName, style: t.titleLarge),
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

                // Une personne que je protège est en SOS.
                if (d != null)
                  for (final s in d.protectedSos) ...[
                    _ProtectedSosBanner(sos: s),
                    const SizedBox(height: Gap.md),
                  ],

                // Statut de protection
                _ProtectionCard(
                  dashboard: d,
                  onTap: () =>
                      _goTab(context, AppTab.smartHome, AppRoutes.smartHome),
                ),
                const SizedBox(height: Gap.md),

                // SOS
                _SosCard(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
                ),
                const SizedBox(height: Gap.md),

                // Transport
                ValueListenableBuilder(
                  valueListenable: TransportRepository.instance.summary,
                  builder: (context, s, _) => _TripCard(
                    trip: s?.activeTrip,
                    onTap: () => s?.activeTrip == null
                        ? Navigator.pushNamed(context, AppRoutes.startTrip)
                        : _goTab(
                            context,
                            AppTab.transport,
                            AppRoutes.transport,
                          ),
                  ),
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
                      subtitle: d?.locationSharing == true
                          ? 'Partage actif'
                          : 'Partage en direct',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.map),
                    ),
                    _QuickAction(
                      icon: Icons.call_rounded,
                      color: AppColors.danger,
                      title: 'Urgences',
                      subtitle: 'Police, pompiers…',
                      onTap: () => showEmergencyNumbersSheet(context),
                    ),
                    _QuickAction(
                      icon: Icons.groups_rounded,
                      color: AppColors.warning,
                      title: 'Mes proches',
                      subtitle: '${d?.contactsCount ?? 0} contact(s)',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.contacts),
                    ),
                    _QuickAction(
                      icon: Icons.volunteer_activism_rounded,
                      color: AppColors.violet,
                      title: 'Je protège',
                      subtitle: '${d?.protectedPeopleCount ?? 0} personne(s)',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.protectedPeople,
                      ),
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
                if (recent.isEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        const IconBadge(
                          icon: Icons.check_rounded,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Text(
                            'Aucune activité récente.',
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final a in recent) ...[
                  AlertTile(
                    alert: a,
                    onTap: () => showAlertDetails(context, a),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar de l'utilisateur : photo si disponible, sinon initiales.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.dashboard, this.size = 48});

  final Dashboard? dashboard;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AccountRepository.instance.avatarUrl,
      builder: (context, url, _) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          border: Border.all(color: AppColors.borderStrong, width: 2),
          image: url == null
              ? null
              : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
        child: url != null
            ? null
            : Text(
                dashboard?.initials ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontSize: size * 0.34,
                ),
              ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _ProtectedSosBanner extends StatelessWidget {
  const _ProtectedSosBanner({required this.sos});

  final Map<String, dynamic> sos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final silent = sos['silent'] == true;
    final name = sos['full_name'] as String? ?? 'Un proche';
    return AppCard(
      onTap: () => InboxService.instance.openLiveTracking(
        userId: sos['user_id'] as String,
        silent: silent,
        name: name,
      ),
      gradient: AppColors.dangerGradient,
      glow: AppColors.danger,
      borderColor: Colors.white.withValues(alpha: 0.2),
      child: Row(
        children: [
          const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  silent ? '$name — alerte discrète' : '$name a besoin d’aide',
                  style: t.titleSmall?.copyWith(color: Colors.white),
                ),
                Text(
                  silent
                      ? 'Ne l’appelez pas. Suivez sa position.'
                      : 'Touchez pour suivre sa position en direct.',
                  style: t.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.dashboard, required this.onTap});

  final Dashboard? dashboard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = dashboard;
    final armed = d?.protectionActive ?? false;
    final status = switch (d?.armMode ?? ArmMode.disarmed) {
      ArmMode.away => 'Armée (absence)',
      ArmMode.home => 'Armée (présence)',
      ArmMode.disarmed => 'Désarmée',
    };
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      radius: Radii.xlAll,
      glow: armed ? AppColors.brand : null,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: armed
            ? const [Color(0xFF2B4FE0), Color(0xFF1A2F8F), Color(0xFF101C55)]
            : const [Color(0xFF2A3350), Color(0xFF182037), Color(0xFF0F1526)],
      ),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: StatusPill(
                  label: armed ? 'Protection active' : 'Protection désactivée',
                  color: armed ? AppColors.success : AppColors.warning,
                ),
              ),
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
                      armed
                          ? 'Tout est sous\ncontrôle'
                          : 'Votre maison\nn’est pas armée',
                      style: t.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      d == null ? 'Chargement…' : '${d.homeName} · $status',
                      style: t.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                armed ? Icons.verified_user_rounded : Icons.shield_outlined,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Metric(
                  value: d == null
                      ? '–'
                      : '${d.camerasOnline}/${d.camerasTotal}',
                  label: 'Caméras',
                ),
                const _MetricDivider(),
                _Metric(value: '${d?.contactsCount ?? '–'}', label: 'Proches'),
                const _MetricDivider(),
                _Metric(
                  value: '${d?.alertsUnresolved ?? '–'}',
                  label: 'À traiter',
                ),
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
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: t.titleMedium?.copyWith(color: Colors.white),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
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

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final Trip? trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tr = trip;
    final late = tr != null && tr.remaining.isNegative;
    final color = tr == null
        ? AppColors.brandBright
        : tr.checkinPending
        ? AppColors.danger
        : late
        ? AppColors.warning
        : AppColors.success;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      radius: Radii.xlAll,
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: tr == null
                ? IconBadge(icon: Icons.route_rounded, color: color, size: 52)
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: tr.progress,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        color: color,
                        backgroundColor: AppColors.surfaceHighest,
                      ),
                      Icon(tr.mode.icon, color: color, size: 22),
                    ],
                  ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr == null ? 'Trajet sécurisé' : tr.destinationLabel,
                  style: t.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tr == null
                      ? 'Taxi, moto, BRT : vos proches vous suivent'
                      : tr.checkinPending
                      ? 'Tout va bien ? Touchez pour répondre'
                      : late
                      ? 'En retard · prévu à ${clock(tr.expectedArrival)}'
                      : 'Arrivée prévue à ${clock(tr.expectedArrival)}',
                  style: t.bodySmall?.copyWith(
                    color: tr?.checkinPending == true
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            tr == null ? Icons.add_rounded : Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
