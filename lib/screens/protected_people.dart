import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/contacts_repository.dart';
import '../services/inbox_service.dart';
import 'app_page.dart';

/// Côté proche : les personnes qui m'ont choisi·e comme contact de confiance.
class ProtectedPeopleScreen extends StatefulWidget {
  const ProtectedPeopleScreen({super.key});

  @override
  State<ProtectedPeopleScreen> createState() => _ProtectedPeopleScreenState();
}

class _ProtectedPeopleScreenState extends State<ProtectedPeopleScreen> {
  final _repo = ContactsRepository.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final d = await AccountRepository.instance.refreshDashboard();
      await _repo.refreshProtected(activeSos: d.protectedSos);
    } on AppException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          e.message,
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
        );
      }
    }
  }

  Future<void> _leave(ProtectedPerson p) async {
    final ok = await confirmAction(
      context,
      title: 'Ne plus protéger ${p.name} ?',
      message:
          'Vous ne recevrez plus ses alertes SOS. ${p.name} en sera informé·e.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Backend.rpc<dynamic>('leave_trusted_contact', {
        'p_owner_id': p.userId,
      });
      await _refresh();
    } catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          toAppException(e).message,
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: _repo.protectedPeople,
      builder: (context, people, _) => AppPage(
        title: 'Je protège',
        subtitle: 'Personnes qui comptent sur vous',
        glow: AppColors.violet,
        onRefresh: _refresh,
        slivers: [
          if (people.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.volunteer_activism_rounded,
                title: 'Personne pour l’instant',
                message:
                    'Quand un proche vous ajoute comme contact de confiance, '
                    'il apparaît ici. Vous serez alerté·e s’il déclenche un SOS.',
              ),
            )
          else
            PageSection(
              child: Column(
                children: [
                  for (final p in people) ...[
                    AppCard(
                      onTap: p.inSos
                          ? () => InboxService.instance.openLiveTracking(
                              userId: p.userId,
                              silent: p.silentSos,
                              name: p.name,
                            )
                          : null,
                      gradient: p.inSos ? AppColors.dangerGradient : null,
                      glow: p.inSos ? AppColors.danger : null,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.violet.withValues(
                              alpha: 0.3,
                            ),
                            child: Text(p.initials, style: t.labelLarge),
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: t.titleSmall),
                                Text(
                                  p.inSos
                                      ? (p.silentSos
                                            ? 'Alerte discrète — ne l’appelez pas'
                                            : 'SOS en cours — touchez pour suivre')
                                      : 'Vous êtes : ${p.relation}',
                                  style: t.bodySmall?.copyWith(
                                    color: p.inSos
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!p.inSos) ...[
                            IconButton(
                              tooltip: 'Appeler',
                              onPressed: () => callNumber(context, p.phone),
                              icon: const Icon(
                                Icons.call_outlined,
                                color: AppColors.success,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Ne plus protéger',
                              onPressed: () => _leave(p),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ] else
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
