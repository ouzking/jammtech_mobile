import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../core/config/env.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/account_repository.dart';
import '../routes.dart';
import '../services/session.dart';
import 'app_page.dart';
import 'home.dart' show UserAvatar;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _account = AccountRepository.instance;
  Uint8List? _localAvatar;
  bool _uploading = false;

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 1024 * 1024) {
        _error('Image trop lourde (1 Mo maximum).');
        return;
      }
      setState(() {
        _localAvatar = bytes;
        _uploading = true;
      });
      await _account.uploadAvatar(bytes);
      if (mounted) showAppSnack(context, 'Photo de profil mise à jour');
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    } catch (_) {
      if (mounted) _error('Impossible d’accéder à la galerie.');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
    await Session.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _export() async {
    try {
      final json = await _account.exportMyData();
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        name: 'jammtech-mes-donnees.json',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: const ['jammtech-mes-donnees.json'],
          subject: 'Mes données JammTech',
        ),
      );
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  Future<void> _deleteAccount() async {
    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (typed != true || !mounted) return;
    try {
      await _account.deleteAccount();
      await Session.signOut();
      if (!mounted) return;
      showAppSnack(context, 'Votre compte a été supprimé.');
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.onboarding,
        (_) => false,
      );
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: _account.dashboard,
      builder: (context, d, _) => AppPage(
        title: 'Profil',
        standalone: widget.standalone,
        glow: AppColors.violet,
        onRefresh: Session.refreshAll,
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
                    onTap: _uploading ? null : _pickImage,
                    semanticLabel: 'Changer la photo de profil',
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _localAvatar != null
                            ? CircleAvatar(
                                radius: 49,
                                backgroundImage: MemoryImage(_localAvatar!),
                              )
                            : UserAvatar(dashboard: d, size: 98),
                        if (_uploading)
                          const Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.all(30),
                              child: CircularProgressIndicator(strokeWidth: 3),
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
                  Text(d?.fullName ?? '…', style: t.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    d?.phoneDisplay ?? '',
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  StatusPill(
                    label: Env.name == 'production' || Env.name == 'demo'
                        ? 'Compte vérifié'
                        : 'Compte vérifié · ${Env.name}',
                    color: AppColors.brandBright,
                  ),
                  const SizedBox(height: Gap.lg),
                  const Divider(),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      _Stat(
                        value: '${d?.alertsTotal ?? '–'}',
                        label: 'Alertes',
                      ),
                      _Stat(
                        value: '${d?.contactsCount ?? '–'}',
                        label: 'Proches',
                      ),
                      _Stat(
                        value: '${d?.devicesCount ?? '–'}',
                        label: 'Appareils',
                      ),
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
                          '${d?.contactsCount ?? 0} personne(s) prévenue(s) en cas de SOS',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.contacts),
                    ),
                    SettingsTile(
                      icon: Icons.volunteer_activism_rounded,
                      color: AppColors.violet,
                      title: 'Personnes que je protège',
                      subtitle: _protectedLabel(d),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.protectedPeople,
                      ),
                    ),
                    SettingsTile(
                      icon: Icons.shield_outlined,
                      color: AppColors.success,
                      title: 'Sécurité',
                      subtitle: 'Codes, biométrie, appareils connectés',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.security),
                    ),
                    SettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Alertes, sons et heures calmes',
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
                const GroupLabel('Mes données'),
                SettingsGroup(
                  children: [
                    SettingsTile(
                      icon: Icons.download_rounded,
                      color: AppColors.info,
                      title: 'Exporter mes données',
                      subtitle: 'Fichier JSON de toutes vos données',
                      onTap: _export,
                    ),
                    SettingsTile(
                      icon: Icons.person_remove_outlined,
                      title: 'Supprimer mon compte',
                      subtitle: 'Définitif : données et fichiers effacés',
                      destructive: true,
                      onTap: _deleteAccount,
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
      ),
    );
  }

  String _protectedLabel(Dashboard? d) {
    final n = d?.protectedPeopleCount ?? 0;
    if (d != null && d.protectedSos.isNotEmpty) return 'SOS en cours !';
    return n == 0 ? 'Personne pour l’instant' : '$n personne(s)';
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

/// Confirmation forte : l'utilisateur doit taper SUPPRIMER.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _c.text.trim().toUpperCase() == 'SUPPRIMER';
    return AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votre profil, vos proches, vos alertes, vos positions et vos '
            'vidéos seront définitivement effacés. Cette action est '
            'irréversible.\n\nTapez SUPPRIMER pour confirmer.',
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _c,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'SUPPRIMER'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Annuler',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Supprimer',
            style: TextStyle(
              color: ok ? AppColors.danger : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
