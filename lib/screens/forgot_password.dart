import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/validators.dart';
import '../core/widgets/widgets.dart';
import '../routes.dart';
import 'auth_layout.dart';
import 'register.dart' show PasswordStrengthMeter;

enum _Step { phone, code, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _codeLength = 6;
  static const _resendDelay = 30;

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.phone;
  bool _loading = false;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [_phone, _otp, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendDelay);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _fakeNetwork() =>
      Future<void>.delayed(const Duration(milliseconds: 800));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_step == _Step.code && _otp.text.length < _codeLength) {
      HapticFeedback.heavyImpact();
      showAppSnack(
        context,
        'Saisissez les $_codeLength chiffres reçus par SMS.',
        icon: Icons.error_outline_rounded,
        color: AppColors.warning,
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _loading = true);
    // TODO: brancher l'envoi / la vérification réels du code SMS.
    await _fakeNetwork();
    if (!mounted) return;
    setState(() => _loading = false);

    switch (_step) {
      case _Step.phone:
        setState(() => _step = _Step.code);
        _startResendTimer();
        showAppSnack(context, 'Code envoyé au +221 ${_phone.text}');
      case _Step.code:
        setState(() => _step = _Step.password);
      case _Step.password:
        showAppSnack(context, 'Mot de passe mis à jour avec succès.');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, cta) = switch (_step) {
      _Step.phone => (
        'Mot de passe oublié',
        'Indiquez votre numéro : nous vous enverrons un code de vérification.',
        Icons.lock_reset_rounded,
        'Recevoir le code',
      ),
      _Step.code => (
        'Vérification',
        'Saisissez le code à $_codeLength chiffres envoyé au +221 ${_phone.text}.',
        Icons.sms_rounded,
        'Vérifier',
      ),
      _Step.password => (
        'Nouveau mot de passe',
        'Choisissez un mot de passe robuste que vous n’utilisez nulle part ailleurs.',
        Icons.key_rounded,
        'Enregistrer',
      ),
    };

    return AuthLayout(
      showBack: true,
      leading: IconBadge(icon: icon, size: 56),
      title: title,
      subtitle: subtitle,
      footer: AuthSwitchLink(
        text: 'Vous vous en souvenez ?',
        link: 'Se connecter',
        onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicator(current: _step.index, total: _Step.values.length),
            const SizedBox(height: Gap.xl),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
            ),
            const SizedBox(height: Gap.xl),
            AppButton(label: cta, loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.phone:
        return AppTextField(
          controller: _phone,
          label: 'Numéro de téléphone',
          icon: Icons.phone_iphone_rounded,
          prefixText: '+221 ',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
            LengthLimitingTextInputFormatter(12),
          ],
          validator: Validators.phone,
          onSubmitted: (_) => _submit(),
        );
      case _Step.code:
        return Column(
          children: [
            OtpField(
              controller: _otp,
              length: _codeLength,
              onCompleted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.lg),
            _resendIn > 0
                ? Text(
                    'Renvoyer le code dans ${_resendIn}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      _otp.clear();
                      _startResendTimer();
                      showAppSnack(context, 'Nouveau code envoyé.');
                    },
                    child: const Text('Renvoyer le code'),
                  ),
          ],
        );
      case _Step.password:
        return Column(
          children: [
            AppTextField(
              controller: _password,
              label: 'Nouveau mot de passe',
              icon: Icons.lock_outline_rounded,
              password: true,
              validator: Validators.password,
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
          ],
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: Motion.medium,
              height: 4,
              decoration: BoxDecoration(
                gradient: i <= current ? AppColors.brandGradient : null,
                color: i <= current ? null : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: Gap.xs),
        ],
      ],
    );
  }
}

/// Saisie de code à cases individuelles, adossée à un seul champ invisible
/// (copier-coller et remplissage automatique SMS fonctionnent nativement).
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();
  String? _lastCompleted;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onFocusChange() => setState(() {});

  void _onTextChange() {
    setState(() {});
    final text = widget.controller.text;
    if (text.length == widget.length && text != _lastCompleted) {
      _lastCompleted = text;
      widget.onCompleted?.call(text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        children: [
          // Champ réel, invisible, qui reçoit la saisie.
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 64,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
          IgnorePointer(
            child: Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: Radii.mdAll,
                        border: Border.all(
                          width: _isActive(i) ? 1.5 : 1,
                          color: _isActive(i)
                              ? AppColors.brand
                              : i < text.length
                              ? AppColors.borderStrong
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        i < text.length ? text[i] : '',
                        style: t.headlineSmall,
                      ),
                    ),
                  ),
                  if (i < widget.length - 1) const SizedBox(width: Gap.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(int i) {
    final len = widget.controller.text.length;
    return _focus.hasFocus &&
        (i == len || (len == widget.length && i == widget.length - 1));
  }
}
