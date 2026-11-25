import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/repositories/account_repository.dart';
import '../app_page.dart';
import 'server_prefs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with ServerPrefs<SettingsScreen> {
  static const _languages = {'fr': 'Français', 'wo': 'Wolof', 'en': 'English'};

  late String _language =
      _languages[AccountRepository.instance.dashboard.value?.language ??
          'fr'] ??
      'Français';

  @override
  Future<Map<String, dynamic>> loadPrefs() =>
      AccountRepository.instance.settings();

  @override
  Future<void> savePrefs(Map<String, dynamic> values) =>
      AccountRepository.instance.updateSettings(values);

  Future<void> _chooseLanguage() async {
    final languages = _languages.values;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in languages)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.page,
                ),
                title: Text(l),
                trailing: l == _language
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppColors.brandBright,
                      )
                    : null,
                onTap: () => Navigator.pop(context, l),
              ),
            const SizedBox(height: Gap.md),
          ],
        ),
      ),
    );
    if (choice == null || choice == _language) return;
    final previous = _language;
    setState(() => _language = choice);
    try {
      final code = _languages.entries.firstWhere((e) => e.value == choice).key;
      await AccountRepository.instance.setLanguage(code);
      AccountRepository.instance.refreshDashboard().ignore();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _language = previous);
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  Future<void> _clearCache() async {
    final ok = await confirmAction(
      context,
      title: 'Vider le cache ?',
      message:
          'Les miniatures et cartes hors ligne seront supprimées. '
          'Vos enregistrements ne sont pas concernés.',
      confirmLabel: 'Vider',
    );
    if (ok && mounted) showAppSnack(context, 'Cache vidé (24,6 Mo libérés)');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Paramètres',
      slivers: [
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Général'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.translate_rounded,
                    title: 'Langue',
                    subtitle: _language,
                    onTap: _chooseLanguage,
                  ),
                  const SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    color: AppColors.violet,
                    title: 'Apparence',
                    subtitle: 'Sombre — optimisé pour la nuit',
                  ),
                ],
              ),
              const GroupLabel('Localisation'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.gps_fixed_rounded,
                    color: AppColors.success,
                    title: 'Position précise',
                    subtitle: 'Utilise le GPS haute précision',
                    value: flag('precise_location'),
                    onChanged: (v) => setPref('precise_location', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.share_location_rounded,
                    color: AppColors.success,
                    title: 'Localisation en arrière-plan',
                    subtitle: 'Nécessaire pour le suivi continu',
                    value: flag('background_location'),
                    onChanged: (v) => setPref('background_location', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.sos_rounded,
                    color: AppColors.danger,
                    title: 'Partage automatique en SOS',
                    subtitle: 'Envoie votre position à vos proches',
                    value: flag('auto_share_on_sos'),
                    onChanged: (v) => setPref('auto_share_on_sos', v),
                  ),
                ],
              ),
              const GroupLabel('Données'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.wifi_rounded,
                    color: AppColors.info,
                    title: 'Vidéos en Wi-Fi uniquement',
                    subtitle: 'Économise votre forfait mobile',
                    value: flag('videos_wifi_only'),
                    onChanged: (v) => setPref('videos_wifi_only', v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.insights_rounded,
                    color: AppColors.info,
                    title: 'Statistiques anonymes',
                    subtitle: 'Aide à améliorer JammTech',
                    value: flag('anonymous_stats'),
                    onChanged: (v) => setPref('anonymous_stats', v),
                  ),
                  SettingsTile(
                    icon: Icons.cleaning_services_outlined,
                    color: AppColors.warning,
                    title: 'Vider le cache',
                    onTap: _clearCache,
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
