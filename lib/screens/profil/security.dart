import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/home_repository.dart';
import '../../routes.dart';
import '../../services/local_security.dart';
import '../app_page.dart';
import '../disarm_keypad.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _local = LocalSecurity.instance;
  bool _twoFactor = false;
  bool _hasDuress = false;
  bool _hasDisarm = false;

  int get _score => [
    _local.pinEnabled,
    _local.biometricsEnabled,
    _twoFactor,
    _hasDuress,
    _local.pinEnabled && _local.autoLock,
  ].where((e) => e).length;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  Future<void> _loadServer() async {
    try {
      final codes = await HomeRepository.instance.securityCodesStatus();
      final totp = await AuthRepository.instance.hasTotp();
      if (!mounted) return;
      setState(() {
        _hasDisarm = codes.hasDisarm;
        _hasDuress = codes.hasDuress;
        _twoFactor = totp;
      });
    } catch (_) {
      // Écran utilisable même hors ligne (réglages locaux).
    }
  }

  void _msg(String m, {bool error = false}) => showAppSnack(
    context,
    m,
    icon: error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
    color: error ? AppColors.danger : AppColors.success,
  );

  // --- PIN local -----------------------------------------------------------

  Future<void> _togglePin(bool enable) async {
    if (!enable) {
      final ok = await confirmAction(
        context,
        title: 'Désactiver le code PIN ?',
        message: 'L’application ne sera plus verrouillée à l’ouverture.',
        confirmLabel: 'Désactiver',
        destructive: true,
      );
      if (!ok) return;
      await _local.removePin();
      if (mounted) setState(() {});
      return;
    }
    final first = await showCodeKeypad(
      context,
      title: 'Nouveau code PIN',
      subtitle: '4 à 8 chiffres',
    );
    if (first == null || !mounted) return;
    final second = await showCodeKeypad(
      context,
      title: 'Confirmez le code PIN',
      subtitle: 'Saisissez-le une seconde fois',
    );
    if (second == null || !mounted) return;
    if (first != second) {
      HapticFeedback.heavyImpact();
      _msg('Les deux codes ne correspondent pas.', error: true);
      return;
    }
    await _local.setPin(first);
    if (mounted) {
      setState(() {});
      _msg('Code PIN activé');
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    if (enable) {
      if (!_local.pinEnabled) {
        _msg('Activez d’abord le code PIN.', error: true);
        return;
      }
      if (!await _local.biometricsAvailable()) {
        if (mounted) {
          _msg('Aucune biométrie configurée sur cet appareil.', error: true);
        }
        return;
      }
      if (!await _local.authenticate('Confirmez pour activer la biométrie')) {
        return;
      }
    }
    await _local.setBiometrics(enable);
    if (mounted) setState(() {});
  }

  // --- Double authentification (TOTP) ---------------------------------------

  Future<void> _toggleTwoFactor(bool enable) async {
    if (!Backend.enabled) {
      _msg('Disponible une fois connecté au serveur.', error: true);
      return;
    }
    try {
      if (!enable) {
        final ok = await confirmAction(
          context,
          title: 'Désactiver la double authentification ?',
          message: 'Votre compte sera protégé par le seul mot de passe.',
          confirmLabel: 'Désactiver',
          destructive: true,
        );
        if (!ok) return;
        await AuthRepository.instance.disableTotp();
        if (mounted) setState(() => _twoFactor = false);
        return;
      }
      final f = await AuthRepository.instance.enrollTotp();
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => _TotpDialog(factorId: f.factorId, secret: f.secret),
      );
      if (ok == true && mounted) {
        setState(() => _twoFactor = true);
        _msg('Double authentification activée');
      }
    } on AppException catch (e) {
      if (mounted) _msg(e.message, error: true);
    }
  }

  // --- Appareils connectés --------------------------------------------------

  Future<void> _showSessions() async {
    List<Map<String, dynamic>> sessions;
    try {
      sessions = await AuthRepository.instance.sessions();
    } on AppException catch (e) {
      if (mounted) _msg(e.message, error: true);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appareils connectés', style: t.headlineSmall),
                const SizedBox(height: Gap.lg),
                for (final s in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: AppCard(
                      color: AppColors.surfaceHigh,
                      child: Row(
                        children: [
                          IconBadge(
                            icon: Icons.smartphone_rounded,
                            color: s['is_current'] == true
                                ? AppColors.success
                                : AppColors.info,
                          ),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _deviceName(s['user_agent'] as String?),
                                  style: t.titleSmall,
                                ),
                                Text(
                                  s['is_current'] == true
                                      ? 'Cet appareil'
                                      : 'Dernière activité : ${(s['updated_at'] as String? ?? '').split('T').first}',
                                  style: t.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (s['is_current'] != true)
                            TextButton(
                              onPressed: () async {
                                try {
                                  await AuthRepository.instance.revokeSession(
                                    s['id'] as String,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  if (mounted) _msg('Appareil déconnecté');
                                } on AppException catch (e) {
                                  if (mounted) _msg(e.message, error: true);
                                }
                              },
                              child: const Text(
                                'Déconnecter',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _deviceName(String? ua) {
    final u = (ua ?? '').toLowerCase();
    if (u.contains('android')) return 'Android';
    if (u.contains('iphone') || u.contains('ios')) return 'iPhone';
    if (u.contains('dart')) return 'Application JammTech';
    return ua == null || ua.isEmpty ? 'Appareil' : ua.split('/').first;
  }

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
      onRefresh: _loadServer,
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
              const GroupLabel('Accès à l’application (sur cet appareil)'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.pin_outlined,
                    title: 'Code PIN',
                    subtitle: 'Demandé à l’ouverture',
                    value: _local.pinEnabled,
                    onChanged: _togglePin,
                  ),
                  SwitchSettingsTile(
                    icon: Icons.fingerprint_rounded,
                    color: AppColors.success,
                    title: 'Empreinte / Face ID',
                    subtitle: 'Déverrouillage biométrique',
                    value: _local.biometricsEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                  SwitchSettingsTile(
                    icon: Icons.timer_outlined,
                    color: AppColors.info,
                    title: 'Verrouillage automatique',
                    subtitle: 'Après 1 minute en arrière-plan',
                    value: _local.autoLock,
                    onChanged: (v) async {
                      await _local.setAutoLock(v);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              const GroupLabel('Maison'),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.dialpad_rounded,
                    color: AppColors.danger,
                    title: 'Codes de désarmement et de contrainte',
                    subtitle: _hasDuress
                        ? 'Code de contrainte défini'
                        : _hasDisarm
                        ? 'Code de contrainte non défini'
                        : 'Aucun code défini',
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.securityCodes,
                      );
                      _loadServer();
                    },
                  ),
                ],
              ),
              const GroupLabel('Compte'),
              SettingsGroup(
                children: [
                  SwitchSettingsTile(
                    icon: Icons.verified_user_outlined,
                    color: AppColors.violet,
                    title: 'Double authentification',
                    subtitle: 'Application d’authentification (TOTP)',
                    value: _twoFactor,
                    onChanged: _toggleTwoFactor,
                  ),
                  SettingsTile(
                    icon: Icons.password_rounded,
                    color: AppColors.warning,
                    title: 'Changer le mot de passe',
                    subtitle: 'Par code SMS',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  ),
                  SettingsTile(
                    icon: Icons.devices_rounded,
                    color: AppColors.info,
                    title: 'Appareils connectés',
                    subtitle: 'Voir et déconnecter',
                    onTap: _showSessions,
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

/// Inscription TOTP : clé à saisir dans l'application d'authentification,
/// puis vérification d'un premier code.
class _TotpDialog extends StatefulWidget {
  const _TotpDialog({required this.factorId, required this.secret});

  final String factorId;
  final String secret;

  @override
  State<_TotpDialog> createState() => _TotpDialogState();
}

class _TotpDialogState extends State<_TotpDialog> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository.instance.verifyTotp(widget.factorId, _code.text);
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Double authentification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dans votre application d’authentification (Google '
            'Authenticator, Authy…), ajoutez un compte avec cette clé :',
          ),
          const SizedBox(height: Gap.sm),
          Pressable(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.secret));
              showAppSnack(context, 'Clé copiée');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: Radii.smAll,
              ),
              child: SelectableText(
                widget.secret,
                style: t.titleSmall?.copyWith(letterSpacing: 1.5),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Code à 6 chiffres',
              errorText: _error,
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
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
          onPressed: _code.text.length == 6 && !_loading ? _verify : null,
          child: const Text('Vérifier'),
        ),
      ],
    );
  }
}
