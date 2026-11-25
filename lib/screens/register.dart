import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/validators.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/repositories/auth_repository.dart';
import '../routes.dart';
import 'auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _acceptedTerms = false;
  bool _termsError = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    setState(() => _termsError = !_acceptedTerms);
    if (!valid || !_acceptedTerms) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthRepository.instance.signUp(
        fullName: _name.text,
        phone: _phone.text,
        password: _password.text,
      );
      if (!mounted) return;
      // Le serveur refuse la connexion tant que le numéro n'est pas vérifié.
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.verifyPhone,
        arguments: _phone.text,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      HapticFeedback.heavyImpact();
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthLayout(
      showBack: true,
      title: 'Créer un compte',
      subtitle: 'Rejoignez JammTech et protégez ce qui compte le plus.',
      footer: AuthSwitchLink(
        text: 'Déjà inscrit ?',
        link: 'Se connecter',
        onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: 'Nom complet',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: Validators.name,
              ),
              const SizedBox(height: Gap.md),
              AppTextField(
                controller: _phone,
                label: 'Numéro de téléphone',
                icon: Icons.phone_iphone_rounded,
                prefixText: '+221 ',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: Validators.phone,
              ),
              const SizedBox(height: Gap.md),
              AppTextField(
                controller: _password,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                password: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.sm),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: Gap.md),
              AppTextField(
                controller: _confirm,
                label: 'Confirmer le mot de passe',
                icon: Icons.lock_reset_rounded,
                password: true,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              const SizedBox(height: Gap.md),
              InkWell(
                borderRadius: Radii.smAll,
                onTap: () => setState(() {
                  _acceptedTerms = !_acceptedTerms;
                  _termsError = false;
                }),
                child: Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() {
                        _acceptedTerms = v ?? false;
                        _termsError = false;
                      }),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'J’accepte les ',
                          style: t.bodySmall?.copyWith(
                            color: _termsError
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          children: const [
                            TextSpan(
                              text: 'conditions d’utilisation',
                              style: TextStyle(color: AppColors.brandBright),
                            ),
                            TextSpan(text: ' et la '),
                            TextSpan(
                              text: 'politique de confidentialité',
                              style: TextStyle(color: AppColors.brandBright),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              AppButton(
                label: 'Créer mon compte',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jauge de robustesse du mot de passe en 4 segments.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const _labels = ['', 'Faible', 'Moyen', 'Bon', 'Excellent'];
  static const _colors = [
    AppColors.surfaceHighest,
    AppColors.danger,
    AppColors.warning,
    AppColors.info,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordStrength(password);
    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: Motion.medium,
              height: 4,
              decoration: BoxDecoration(
                color: i <= score ? _colors[score] : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < 4) const SizedBox(width: 6),
        ],
        const SizedBox(width: Gap.sm),
        SizedBox(
          width: 64,
          child: Text(
            _labels[score],
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: _colors[score]),
          ),
        ),
      ],
    );
  }
}
