import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../app_page.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // TODO: synchroniser avec le service de notifications push.
  bool _intrusions = true;
  bool _zones = true;
  bool _devices = true;
  bool _family = true;
  bool _sound = true;
  bool _vibration = true;
  bool _quietHours = false;
  TimeOfDay _quietFrom = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietTo = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _pickTime(bool from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _quietFrom : _quietTo,
    );
    if (picked == null) return;
    setState(() => from ? _quietFrom = picked : _quietTo = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Notifications',
      slivers: [
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderColor: AppColors.danger.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.priority_high_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'Les alertes SOS de vos proches passent toujours, '
                        'même en mode silencieux.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const GroupLabel('Types d’alertes'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.gpp_maybe_rounded,
                    color: AppColors.danger,
                    title: 'Intrusions',
                    subtitle: 'Mouvement détecté, porte forcée',
                    value: _intrusions,
                    onChanged: (v) => setState(() => _intrusions = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    title: 'Zones à risque',
                    subtitle: 'Incidents signalés à proximité',
                    value: _zones,
                    onChanged: (v) => setState(() => _zones = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.router_outlined,
                    color: AppColors.info,
                    title: 'État des appareils',
                    subtitle: 'Caméra hors ligne, batterie faible',
                    value: _devices,
                    onChanged: (v) => setState(() => _devices = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.family_restroom_rounded,
                    color: AppColors.violet,
                    title: 'Activité des proches',
                    subtitle: 'Arrivées, départs, partages',
                    value: _family,
                    onChanged: (v) => setState(() => _family = v),
                  ),
                ],
              ),
              const GroupLabel('Sons & vibrations'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Son',
                    value: _sound,
                    onChanged: (v) => setState(() => _sound = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.vibration_rounded,
                    title: 'Vibration',
                    value: _vibration,
                    onChanged: (v) => setState(() => _vibration = v),
                  ),
                ],
              ),
              const GroupLabel('Ne pas déranger'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.bedtime_outlined,
                    color: AppColors.violet,
                    title: 'Heures calmes',
                    subtitle: 'Seules les alertes critiques sonnent',
                    value: _quietHours,
                    onChanged: (v) => setState(() => _quietHours = v),
                  ),
                  if (_quietHours) ...[
                    SettingsTile(
                      icon: Icons.nightlight_outlined,
                      color: AppColors.violet,
                      title: 'Début',
                      trailing: Text(_quietFrom.format(context)),
                      onTap: () => _pickTime(true),
                    ),
                    SettingsTile(
                      icon: Icons.wb_sunny_outlined,
                      color: AppColors.warning,
                      title: 'Fin',
                      trailing: Text(_quietTo.format(context)),
                      onTap: () => _pickTime(false),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
