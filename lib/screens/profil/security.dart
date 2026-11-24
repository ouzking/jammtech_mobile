import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../../routes.dart';
import '../app_page.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  // TODO: brancher sur local_auth et le backend.
  bool _pin = true;
  bool _biometrics = true;
  bool _twoFactor = false;
  bool _duressCode = false;
  bool _autoLock = true;

  int get _score => [
    _pin,
    _biometrics,
    _twoFactor,
    _duressCode,
    _autoLock,
  ].where((e) => e).length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final score = _score;
    final level = score >= 4
        ? ('Excellente', AppColors.success)
        : score >= 3
        ? ('Bonne', AppColors.info)
        : ('À renforcer', AppColors.warning);

    return AppPage(
      title: 'Sécurité',
      glow: AppColors.success,
      slivers: [
        PageSection(
          child: AppCard(
            padding: const EdgeInsets.all(Gap.lg),
            radius: Radii.xlAll,
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: score / 5),
                    duration: Motion.slow,
                    curve: Motion.emphasized,
                    builder: (_, v, _) => Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: level.$2,
                          backgroundColor: AppColors.surfaceHighest,
                        ),
                        Center(child: Text('$score/5', style: t.titleMedium)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Niveau de protection',
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.$1,
                        style: t.titleLarge?.copyWith(color: level.$2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        score >= 4
                            ? 'Votre compte est très bien protégé.'
                            : 'Activez plus d’options pour renforcer votre compte.',
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Accès à l’application'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.pin_outlined,
                    title: 'Code PIN',
                    subtitle: 'Demandé à l’ouverture',
                    value: _pin,
                    onChanged: (v) => setState(() => _pin = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.fingerprint_rounded,
                    color: AppColors.success,
                    title: 'Empreinte / Face ID',
                    subtitle: 'Déverrouillage biométrique',
                    value: _biometrics,
                    onChanged: (v) => setState(() => _biometrics = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.timer_outlined,
                    color: AppColors.info,
                    title: 'Verrouillage automatique',
                    subtitle: 'Après 1 minute d’inactivité',
                    value: _autoLock,
                    onChanged: (v) => setState(() => _autoLock = v),
                  ),
                ],
              ),
              const GroupLabel('Protection avancée'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.verified_user_outlined,
                    color: AppColors.violet,
                    title: 'Double authentification',
                    subtitle: 'Code SMS à chaque nouvelle connexion',
                    value: _twoFactor,
                    onChanged: (v) => setState(() => _twoFactor = v),
                  ),
                  SwitchSettingsTile(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    title: 'Code de contrainte',
                    subtitle:
                        'Un code secret qui semble désarmer mais déclenche un SOS silencieux',
                    value: _duressCode,
                    onChanged: (v) => setState(() => _duressCode = v),
                  ),
                ],
              ),
              const GroupLabel('Compte'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.password_rounded,
                    color: AppColors.warning,
                    title: 'Changer le mot de passe',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  ),
                  SettingsTile(
                    icon: Icons.devices_rounded,
                    color: AppColors.info,
                    title: 'Appareils connectés',
                    subtitle: 'Cet appareil · Actif maintenant',
                    onTap: () => showAppSnack(
                      context,
                      'Seul cet appareil est connecté.',
                      icon: Icons.devices_rounded,
                      color: AppColors.info,
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
