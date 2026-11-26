import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../data/repositories/transport_repository.dart';
import '../../routes.dart';
import '../app_page.dart';

/// Pilier Transport : trajet en cours, proches en route, historique, véhicules.
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final _repo = TransportRepository.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Compte à rebours + relecture de l'état serveur (« Tout va bien ? »
    // visible même sans notification push).
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() {});
      if (_repo.activeTrip != null ||
          (_repo.summary.value?.watched.isNotEmpty ?? false)) {
        _repo.refresh().ignore();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await _repo.refresh();
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  Future<void> _arrive(Trip t) async {
    HapticFeedback.heavyImpact();
    try {
      await _repo.arrive(t.id);
      if (mounted) {
        showAppSnack(context, 'Bien arrivé·e ! Vos proches sont prévenus.');
      }
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  Future<void> _cancel(Trip t) async {
    final ok = await confirmAction(
      context,
      title: 'Annuler le trajet ?',
      message: 'Le suivi s’arrête et vos proches sont prévenus.',
      confirmLabel: 'Annuler le trajet',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.cancel(t.id);
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  Future<void> _extend(Trip t) async {
    try {
      await _repo.extend(t.id, 15);
      if (mounted) {
        showAppSnack(
          context,
          'Arrivée repoussée de 15 min',
          icon: Icons.more_time_rounded,
          color: AppColors.info,
        );
      }
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: _repo.summary,
      builder: (context, s, _) {
        final active = s?.activeTrip;
        return AppPage(
          title: 'Trajets',
          subtitle: 'Arrivez en sécurité, vos proches veillent',
          standalone: widget.standalone,
          glow: active != null ? AppColors.success : AppColors.brand,
          onRefresh: _refresh,
          slivers: [
            PageSection(
              child: active != null
                  ? _ActiveTripCard(
                      trip: active,
                      onArrive: () => _arrive(active),
                      onExtend: () => _extend(active),
                      onCancel: () => _cancel(active),
                      onCheckin: () =>
                          Navigator.pushNamed(context, AppRoutes.tripCheckin),
                    )
                  : _StartCard(
                      onStart: () async {
                        await Navigator.pushNamed(context, AppRoutes.startTrip);
                        _refresh();
                      },
                    ),
            ),
            if (s != null && s.watched.isNotEmpty)
              PageSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Proches en route'),
                    for (final w in s.watched) ...[
                      _WatchedTile(trip: w),
                      const SizedBox(height: Gap.sm),
                    ],
                  ],
                ),
              ),
            PageSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Comment ça marche'),
                  const _HowItWorks(),
                ],
              ),
            ),
            if (s != null && s.recent.isNotEmpty)
              PageSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Trajets récents'),
                    SettingsGroup(
                      children: [
                        for (final r in s.recent.take(5))
                          SettingsTile(
                            icon: r.mode.icon,
                            color: switch (r.status) {
                              TripStatus.arrived => AppColors.success,
                              TripStatus.escalated => AppColors.danger,
                              _ => AppColors.textSecondary,
                            },
                            title: r.destinationLabel,
                            subtitle:
                                '${dayLabel(r.startedAt)} · ${clock(r.startedAt)} · ${switch (r.status) {
                                  TripStatus.arrived => 'Arrivé·e',
                                  TripStatus.cancelled => 'Annulé',
                                  TripStatus.escalated => 'Alerte déclenchée',
                                  TripStatus.expired => 'Expiré',
                                  TripStatus.active => 'En cours',
                                }}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            PageSection(
              bottom: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Mes véhicules'),
                  AppCard(
                    child: Row(
                      children: [
                        const IconBadge(
                          icon: Icons.gps_fixed_rounded,
                          color: AppColors.violet,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (s?.vehicles.isNotEmpty ?? false)
                                    ? '${s!.vehicles.length} véhicule(s) protégé(s)'
                                    : 'Traceur GPS anti-vol',
                                style: t.titleSmall,
                              ),
                              Text(
                                'Alerte si votre voiture ou moto bouge la nuit, '
                                'sort d’une zone ou si le traceur est débranché.',
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                        const StatusPill(
                          label: 'Bientôt',
                          color: AppColors.violet,
                          dot: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      radius: Radii.xlAll,
      glow: AppColors.brand,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B63FF), Color(0xFF1641C4), Color(0xFF0E1E5C)],
      ),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: Radii.mdAll,
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  for (final m in [
                    TripMode.taxi,
                    TripMode.moto,
                    TripMode.public,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        m.icon,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Text(
            'Trajet sécurisé',
            style: t.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Taxi, clando, moto ou BRT : vos proches suivent votre trajet. '
            'Si vous n’arrivez pas, l’alerte part toute seule.',
            style: t.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Pressable(
            onTap: onStart,
            semanticLabel: 'Démarrer un trajet',
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Radii.mdAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.brandDeep,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Démarrer un trajet',
                    style: t.labelLarge?.copyWith(color: AppColors.brandDeep),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({
    required this.trip,
    required this.onArrive,
    required this.onExtend,
    required this.onCancel,
    required this.onCheckin,
  });

  final Trip trip;
  final VoidCallback onArrive;
  final VoidCallback onExtend;
  final VoidCallback onCancel;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final remaining = trip.remaining;
    final late = remaining.isNegative;
    final color = trip.checkinPending || trip.status == TripStatus.escalated
        ? AppColors.danger
        : late
        ? AppColors.warning
        : AppColors.success;
    final minutes = remaining.inMinutes.abs();

    return Column(
      children: [
        if (trip.checkinPending) ...[
          AppCard(
            onTap: onCheckin,
            gradient: AppColors.dangerGradient,
            glow: AppColors.danger,
            borderColor: Colors.white.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.help_rounded, color: Colors.white, size: 30),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'Tout va bien ? Répondez pour éviter l’alerte.',
                    style: t.titleSmall?.copyWith(color: Colors.white),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
        ],
        AppCard(
          padding: const EdgeInsets.all(Gap.lg),
          radius: Radii.xlAll,
          glow: color,
          borderColor: color.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    label: trip.status == TripStatus.escalated
                        ? 'Alerte en cours'
                        : late
                        ? 'En retard'
                        : 'Trajet en cours',
                    color: color,
                  ),
                  const Spacer(),
                  Icon(trip.mode.icon, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    trip.mode.label,
                    style: t.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: trip.progress,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: AppColors.surfaceHighest,
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                late ? '+$minutes' : '$minutes',
                                style: t.headlineSmall,
                              ),
                              Text(
                                'min',
                                style: t.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.destinationLabel,
                          style: t.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Arrivée prévue à ${clock(trip.expectedArrival)}',
                          style: t.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (trip.plateDisplay != null) ...[
                          const SizedBox(height: Gap.xs),
                          _PlateBadge(plate: trip.plateDisplay!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              AppButton(
                label: 'Je suis arrivé·e',
                icon: Icons.where_to_vote_rounded,
                onPressed: onArrive,
              ),
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: '+15 min',
                      icon: Icons.more_time_rounded,
                      onPressed: trip.extensions >= 3 ? null : onExtend,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Annuler',
                      icon: Icons.close_rounded,
                      onPressed: onCancel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Si vous n’êtes pas arrivé·e ${trip.graceMinutes} min après '
                      'l’heure prévue, nous vous demandons si tout va bien, '
                      'puis vos proches sont alertés.',
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plaque d'immatriculation stylisée.
class _PlateBadge extends StatelessWidget {
  const _PlateBadge({required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        plate,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.black,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WatchedTile extends StatelessWidget {
  const _WatchedTile({required this.trip});

  final WatchedTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final late = trip.expectedArrival.isBefore(DateTime.now());
    return AppCard(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.watchTrip,
        arguments: trip.tripId,
      ),
      borderColor:
          (trip.status == TripStatus.escalated
                  ? AppColors.danger
                  : late
                  ? AppColors.warning
                  : AppColors.success)
              .withValues(alpha: 0.35),
      child: Row(
        children: [
          IconBadge(
            icon: trip.mode.icon,
            color: trip.status == TripStatus.escalated
                ? AppColors.danger
                : AppColors.success,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.travelerName} → ${trip.destinationLabel}',
                  style: t.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trip.status == TripStatus.escalated
                      ? 'Alerte en cours'
                      : late
                      ? 'En retard · prévu à ${clock(trip.expectedArrival)}'
                      : 'Arrivée prévue à ${clock(trip.expectedArrival)}',
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const StatusPill(label: 'En direct'),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const steps = [
      (
        Icons.route_rounded,
        'Indiquez votre destination',
        'Et, en taxi ou moto, la plaque du véhicule.',
      ),
      (
        Icons.visibility_rounded,
        'Vos proches vous suivent',
        'En direct dans l’app, ou par SMS avec un lien.',
      ),
      (
        Icons.notifications_active_rounded,
        'Un retard ? On vérifie',
        'Nous vous demandons si tout va bien, même téléphone éteint.',
      ),
      (
        Icons.sos_rounded,
        'Pas de réponse : alerte',
        'Vos proches reçoivent votre dernière position.',
      ),
    ];
    return SettingsGroup(
      children: [
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: t.labelMedium?.copyWith(
                      color: AppColors.brandBright,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$2, style: t.titleSmall),
                      Text(
                        s.$3,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(s.$1, size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
      ],
    );
  }
}
