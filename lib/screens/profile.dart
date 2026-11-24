import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import '../routes.dart';
import 'app_page.dart';
import 'emergency_sheets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Octets plutôt que File : fonctionne aussi sur le Web.
  Uint8List? _avatar;

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _avatar = bytes);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Impossible d’accéder à la galerie.',
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Se déconnecter ?',
      message:
          'Vous ne recevrez plus d’alertes sur cet appareil jusqu’à votre '
          'prochaine connexion.',
      confirmLabel: 'Déconnexion',
      destructive: true,
    );
    if (!ok || !mounted) return;
    // TODO: invalider la session côté serveur.
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Profil',
      standalone: widget.standalone,
      glow: AppColors.violet,
      actions: [
        GlassIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Paramètres',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
      ],
      slivers: [
        // Identité
        PageSection(
          child: AppCard(
            padding: const EdgeInsets.all(Gap.lg),
            radius: Radii.xlAll,
            child: Column(
              children: [
                Pressable(
                  onTap: _pickImage,
                  semanticLabel: 'Changer la photo de profil',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.brandGradient,
                        ),
                        child: CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.surfaceHigh,
                          backgroundImage: _avatar == null
                              ? null
                              : MemoryImage(_avatar!),
                          child: _avatar == null
                              ? Text(
                                  DemoData.userName
                                      .split(' ')
                                      .map((p) => p[0])
                                      .take(2)
                                      .join(),
                                  style: t.headlineSmall,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.md),
                Text(DemoData.userName, style: t.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  DemoData.userPhone,
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Gap.sm),
                const StatusPill(
                  label: 'Compte vérifié',
                  color: AppColors.brandBright,
                ),
                const SizedBox(height: Gap.lg),
                const Divider(),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    _Stat(value: '${DemoData.alerts.length}', label: 'Alertes'),
                    _Stat(
                      value: '${DemoData.contacts.length}',
                      label: 'Proches',
                    ),
                    const _Stat(value: '4', label: 'Appareils'),
                  ],
                ),
              ],
            ),
          ),
        ),

        PageSection(
          bottom: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Protection'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.groups_rounded,
                    color: AppColors.warning,
                    title: 'Contacts de confiance',
                    subtitle:
                        '${DemoData.contacts.length} personnes prévenues en cas de SOS',
                    onTap: () => showTrustedContactsSheet(context),
                  ),
                  SettingsTile(
                    icon: Icons.shield_outlined,
                    color: AppColors.success,
                    title: 'Sécurité du compte',
                    subtitle: 'Code PIN, biométrie, appareils',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.security),
                  ),
                  SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Alertes, sons et vibrations',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                ],
              ),
              const GroupLabel('Application'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.tune_rounded,
                    color: AppColors.violet,
                    title: 'Paramètres',
                    subtitle: 'Langue, localisation, données',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                  SettingsTile(
                    icon: Icons.help_outline_rounded,
                    color: AppColors.info,
                    title: 'Aide & assistance',
                    subtitle: 'FAQ, nous contacter',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.help),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Déconnexion',
                    destructive: true,
                    trailing: const SizedBox.shrink(),
                    onTap: _logout,
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),
              Center(
                child: Text(
                  'JammTech · Version 1.0.0',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: t.headlineSmall),
          const SizedBox(height: 2),
          Text(
            label,
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
