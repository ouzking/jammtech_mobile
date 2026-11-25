import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/widgets.dart';
import '../services/local_security.dart';
import 'disarm_keypad.dart';

/// Écran de verrouillage (PIN local ou biométrie).
///
/// Le bouton SOS reste accessible sans déverrouiller : en danger, on ne doit
/// jamais avoir à saisir un code pour alerter.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked, this.onSos});

  final VoidCallback onUnlocked;
  final VoidCallback? onSos;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _sec = LocalSecurity.instance;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    if (_sec.biometricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  Future<void> _biometric() async {
    if (await _sec.authenticate('Déverrouillez JammTech')) {
      widget.onUnlocked();
    }
  }

  Future<void> _check(String pin) async {
    if (await _sec.checkPin(pin)) {
      widget.onUnlocked();
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _failures++);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: widget.onSos == null
                        ? const SizedBox.shrink()
                        : Pressable(
                            onTap: widget.onSos,
                            semanticLabel: 'SOS',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.dangerGradient,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const Spacer(),
                const BrandMark(size: 64),
                const SizedBox(height: Gap.xl),
                CodeKeypad(
                  title: 'JammTech est verrouillé',
                  subtitle: _failures == 0
                      ? 'Saisissez votre code PIN'
                      : 'Code incorrect ($_failures)',
                  onSubmit: _check,
                ),
                if (_sec.biometricsEnabled)
                  TextButton.icon(
                    onPressed: _biometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Utiliser la biométrie'),
                  ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
