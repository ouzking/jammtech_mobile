import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../../data/repositories/account_repository.dart';
import '../app_page.dart';
import 'server_prefs.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with ServerPrefs<NotificationsScreen> {
  @override
  Future<Map<String, dynamic>> loadPrefs() =>
      AccountRepository.instance.notificationPreferences();

  @override
  Future<void> savePrefs(Map<String, dynamic> values) =>
      AccountRepository.instance.updateNotificationPreferences(values);

  /// « 22:00:00 » → TimeOfDay (heure de Dakar, comme le serveur).
  TimeOfDay _time(String key, TimeOfDay fallback) {
    final parts = (prefs[key] as String? ?? '').split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  TimeOfDay get _quietFrom =>
      _time('quiet_hours_start', const TimeOfDay(hour: 22, minute: 0));
  TimeOfDay get _quietTo =>
      _time('quiet_hours_end', const TimeOfDay(hour: 7, minute: 0));

  Future<void> _pickTime(bool from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _quietFrom : _quietTo,
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await setPref(from ? 'quiet_hours_start' : 'quiet_hours_end', v);
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
              const GroupLabel('Notifications push'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.gpp_maybe_rounded,
                    color: AppColors.danger,
                    title: 'Intrusions',
                    subtitle: 'Mouvement détecté, porte forcée',
                    value: flag('intrusions_push'),
                    onChanged: (v) => setPref('intrusions_push', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    title: 'Zones à risque',
                    subtitle: 'Incidents signalés à proximité',
                    value: flag('zones_push'),
                    onChanged: (v) => setPref('zones_push', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.router_outlined,
                    color: AppColors.info,
                    title: 'État des appareils',
                    subtitle: 'Caméra hors ligne, batterie faible',
                    value: flag('devices_push'),
                    onChanged: (v) => setPref('devices_push', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.family_restroom_rounded,
                    color: AppColors.violet,
                    title: 'Activité des proches',
                    subtitle: 'Arrivées, départs, partages',
                    value: flag('contacts_push'),
                    onChanged: (v) => setPref('contacts_push', v),
                  ),
                ],
              ),
              const GroupLabel('SMS'),
              SettingsGroup(
                children: [
                  for (final (key, title) in const [
                    ('intrusions_sms', 'Intrusions'),
                    ('zones_sms', 'Zones à risque'),
                    ('devices_sms', 'État des appareils'),
                    ('contacts_sms', 'Activité des proches'),
                  ])
                    SwitchSettingsTile(
                      icon: Icons.sms_outlined,
                      color: AppColors.info,
                      title: title,
                      value: flag(key),
                      onChanged: (v) => setPref(key, v),
                    ),
                ],
              ),
              const GroupLabel('Sons & vibrations'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.volume_up_outlined,
                    title: 'Son',
                    value: flag('sound'),
                    onChanged: (v) => setPref('sound', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.vibration_rounded,
                    title: 'Vibration',
                    value: flag('vibration'),
                    onChanged: (v) => setPref('vibration', v),
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
                    value: flag('quiet_hours_enabled'),
                    onChanged: (v) => setPref('quiet_hours_enabled', v),
                  ),
                  if (flag('quiet_hours_enabled')) ...[
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
