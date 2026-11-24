import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../app_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // TODO: persister ces préférences (shared_preferences / backend).
  bool _preciseLocation = true;
  bool _backgroundLocation = true;
  bool _autoShareOnSos = true;
  bool _wifiOnlyUploads = false;
  bool _analytics = true;
  String _language = 'Français';

  Future<void> _chooseLanguage() async {
    const languages = ['Français', 'Wolof', 'English'];
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
    if (choice != null) setState(() => _language = choice);
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
                    value: _preciseLocation,
                    onChanged: (v) => setState(() => _preciseLocation = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.share_location_rounded,
                    color: AppColors.success,
                    title: 'Localisation en arrière-plan',
                    subtitle: 'Nécessaire pour le suivi continu',
                    value: _backgroundLocation,
                    onChanged: (v) => setState(() => _backgroundLocation = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.sos_rounded,
                    color: AppColors.danger,
                    title: 'Partage automatique en SOS',
                    subtitle: 'Envoie votre position à vos proches',
                    value: _autoShareOnSos,
                    onChanged: (v) => setState(() => _autoShareOnSos = v),
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
                    value: _wifiOnlyUploads,
                    onChanged: (v) => setState(() => _wifiOnlyUploads = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.insights_rounded,
                    color: AppColors.info,
                    title: 'Statistiques anonymes',
                    subtitle: 'Aide à améliorer JammTech',
                    value: _analytics,
                    onChanged: (v) => setState(() => _analytics = v),
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
