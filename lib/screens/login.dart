import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/validators.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/repositories/auth_repository.dart';
import '../routes.dart';
import '../services/session.dart';
import 'auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthRepository.instance.signIn(_phone.text, _password.text);
      Session.onSignedIn().ignore();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      HapticFeedback.heavyImpact();
      // Numéro non vérifié : on renvoie un code et on ouvre la vérification.
      if (e.code == 'phone_not_confirmed') {
        AuthRepository.instance.resendSignupOtp(_phone.text).ignore();
        Navigator.pushNamed(
          context,
          AppRoutes.verifyPhone,
          arguments: _phone.text,
        );
      }
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
    return AuthLayout(
      title: 'Bon retour',
      subtitle: 'Connectez-vous pour accéder à votre espace sécurisé.',
      footer: AuthSwitchLink(
        text: 'Pas encore de compte ?',
        link: 'Créer un compte',
        onTap: () => Navigator.pushNamed(context, AppRoutes.register),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.password,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.forgotPassword),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: Gap.sm),
              AppButton(
                label: 'Se connecter',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: Gap.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connexion sécurisée',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
