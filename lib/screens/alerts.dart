import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import '../routes.dart';
import 'app_page.dart';

enum _Filter { all, open, critical, resolved }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => 'Toutes',
    _Filter.open => 'À traiter',
    _Filter.critical => 'Critiques',
    _Filter.resolved => 'Traitées',
  };

  bool matches(SecurityAlert a) => switch (this) {
    _Filter.all => true,
    _Filter.open => !a.resolved,
    _Filter.critical => a.severity == AlertSeverity.critical,
    _Filter.resolved => a.resolved,
  };
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _Filter _filter = _Filter.all;

  void _toggleResolved(SecurityAlert a) {
    final resolved = !a.resolved;
    DemoData.setResolved(a, resolved);
    showAppSnack(
      context,
      resolved ? 'Alerte marquée comme traitée' : 'Alerte rouverte',
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () => DemoData.setResolved(a, !resolved),
      ),
    );
  }

  void _resolveAll() {
    final open = DemoData.alerts.where((a) => !a.resolved).toList();
    if (open.isEmpty) return;
    for (final a in open) {
      a.resolved = true;
    }
    DemoData.alertsRevision.value++;
    showAppSnack(
      context,
      '${open.length} alerte(s) marquée(s) comme traitée(s)',
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () {
          for (final a in open) {
            a.resolved = false;
          }
          DemoData.alertsRevision.value++;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DemoData.alertsRevision,
      builder: (context, _, _) {
        final items = DemoData.alerts.where(_filter.matches).toList();
        final open = DemoData.unresolvedCount;

        return AppPage(
          title: 'Alertes',
          subtitle: open == 0
              ? 'Aucune alerte en attente'
              : '$open alerte${open > 1 ? 's' : ''} à traiter',
          standalone: widget.standalone,
          actions: [
            GlassIconButton(
              icon: Icons.done_all_rounded,
              tooltip: 'Tout marquer comme traité',
              onPressed: open == 0 ? null : _resolveAll,
            ),
          ],
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                  itemCount: _Filter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
                  itemBuilder: (_, i) {
                    final f = _Filter.values[i];
                    final count = DemoData.alerts.where(f.matches).length;
                    return ChoiceChip(
                      label: Text('${f.label}  $count'),
                      selected: f == _filter,
                      onSelected: (_) => setState(() => _filter = f),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Gap.lg)),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'Rien à signaler',
                  message: 'Aucune alerte ne correspond à ce filtre.',
                  action: AppButton.secondary(
                    label: 'Voir toutes les alertes',
                    expand: false,
                    onPressed: () => setState(() => _filter = _Filter.all),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                  itemBuilder: (context, i) {
                    final a = items[i];
                    return _Entrance(
                      index: i,
                      child: Dismissible(
                        key: ValueKey('${a.id}-${a.resolved}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          _toggleResolved(a);
                          return false;
                        },
                        background: _SwipeBackground(resolved: a.resolved),
                        child: AlertTile(
                          alert: a,
                          onTap: () => showAlertDetails(context, a),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.resolved});

  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.warning : AppColors.success;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Gap.xl),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: Radii.lgAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            resolved ? 'Rouvrir' : 'Traitée',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
          const SizedBox(width: Gap.xs),
          Icon(
            resolved ? Icons.replay_rounded : Icons.check_circle_rounded,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// Apparition échelonnée des éléments de liste.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 60 * index.clamp(0, 8)),
      curve: Motion.emphasized,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Ligne d'alerte, réutilisée sur l'accueil.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert, this.onTap});

  final SecurityAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = alert.severity;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Liseré de sévérité
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: Gap.md),
              decoration: BoxDecoration(
                color: alert.resolved ? AppColors.surfaceHighest : s.color,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.sm,
                  Gap.md,
                  Gap.md,
                  Gap.md,
                ),
                child: Row(
                  children: [
                    IconBadge(
                      icon: alert.resolved ? Icons.check_rounded : s.icon,
                      color: alert.resolved ? AppColors.textTertiary : s.color,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall?.copyWith(
                              color: alert.resolved
                                  ? AppColors.textSecondary
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  alert.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: Gap.xs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timeAgo(alert.time),
                          style: t.labelMedium?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (!alert.resolved) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fiche détaillée d'une alerte.
Future<void> showAlertDetails(BuildContext context, SecurityAlert alert) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = Theme.of(sheetContext).textTheme;
      final s = alert.severity;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon: s.icon, color: s.color, size: 52),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(
                          label: alert.resolved ? 'Traitée' : s.label,
                          color: alert.resolved
                              ? AppColors.textSecondary
                              : s.color,
                        ),
                        const SizedBox(height: 6),
                        Text(alert.title, style: t.titleLarge),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Text(
                alert.description,
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: Gap.lg),
              AppCard(
                color: AppColors.surfaceHigh,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.place_outlined,
                      label: 'Lieu',
                      value: alert.location,
                    ),
                    const SizedBox(height: Gap.sm),
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Heure',
                      value: '${dayLabel(alert.time)} à ${clock(alert.time)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Vidéo',
                      icon: Icons.play_circle_outline_rounded,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(context, AppRoutes.videoHistory);
                      },
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: AppButton(
                      label: alert.resolved ? 'Rouvrir' : 'Traitée',
                      icon: alert.resolved
                          ? Icons.replay_rounded
                          : Icons.check_rounded,
                      onPressed: () {
                        DemoData.setResolved(alert, !alert.resolved);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: Gap.sm),
        Text(
          label,
          style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(value, style: t.titleSmall),
      ],
    );
  }
}
