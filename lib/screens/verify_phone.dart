import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/repositories/auth_repository.dart';
import '../routes.dart';
import '../services/session.dart';
import 'auth_layout.dart';
import 'forgot_password.dart' show OtpField;

/// Vérification du numéro après l'inscription (obligatoire avant la connexion).
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key, required this.phone});

  final String phone;

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  static const _resendDelay = 30;

  final _otp = TextEditingController();
  bool _loading = false;
  int _resendIn = _resendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_otp.text.length < 6 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await AuthRepository.instance.verifyOtp(widget.phone, _otp.text);
      Session.onSignedIn().ignore();
      if (!mounted) return;
      showAppSnack(context, 'Numéro vérifié. Bienvenue sur JammTech !');
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _otp.clear();
      HapticFeedback.heavyImpact();
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  Future<void> _resend() async {
    try {
      await AuthRepository.instance.resendSignupOtp(widget.phone);
      _otp.clear();
      _startTimer();
      if (mounted) showAppSnack(context, 'Nouveau code envoyé.');
    } on AppException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          e.message,
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      leading: const IconBadge(icon: Icons.sms_rounded, size: 56),
      title: 'Vérifiez votre numéro',
      subtitle:
          'Saisissez le code à 6 chiffres envoyé au +221 ${widget.phone}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OtpField(controller: _otp, onCompleted: (_) => _verify()),
          const SizedBox(height: Gap.lg),
          Center(
            child: _resendIn > 0
                ? Text(
                    'Renvoyer le code dans ${_resendIn}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  )
                : TextButton(
                    onPressed: _resend,
                    child: const Text('Renvoyer le code'),
                  ),
          ),
          const SizedBox(height: Gap.xl),
          AppButton(label: 'Vérifier', loading: _loading, onPressed: _verify),
        ],
      ),
    );
  }
}
