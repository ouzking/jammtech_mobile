import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/repositories/transport_repository.dart';
import '../../routes.dart';
import '../../services/location_service.dart';
import '../disarm_keypad.dart' show CodeKeypad;

/// « Tout va bien ? » pendant un trajet (push `trip_checkin`, ou état serveur).
///
/// ⚠️ Code de contrainte accepté : ce chemin est **strictement identique** quel
/// que soit le code (même message, même vibration, même écran) et la position
/// est envoyée à chaque fois. Ne jamais ajouter de condition sur la réponse.
class TripCheckinScreen extends StatefulWidget {
  const TripCheckinScreen({super.key, this.round = 1});

  /// 1 = première question, 2 = relance (l'alerte est imminente).
  final int round;

  @override
  State<TripCheckinScreen> createState() => _TripCheckinScreenState();
}

class _TripCheckinScreenState extends State<TripCheckinScreen> {
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  Future<void> _submit(String code) async {
    final trip = TransportRepository.instance.activeTrip;
    if (trip == null || _sending) {
      if (trip == null) Navigator.maybePop(context);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    // Position toujours envoyée, avec le même délai maximal.
    final p = await LocationService.instance
        .currentPosition()
        .timeout(const Duration(seconds: 2), onTimeout: () => null)
        .catchError((_) => null);
    try {
      await TransportRepository.instance.checkin(
        trip.id,
        code,
        lat: p?.latitude,
        lng: p?.longitude,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      showAppSnack(context, 'Merci. Bonne fin de trajet !');
      Navigator.maybePop(context);
    } on AppException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final trip = TransportRepository.instance.activeTrip;
    final urgent = widget.round >= 2;
    return Scaffold(
      body: AppBackground(
        glow: urgent ? AppColors.danger : AppColors.warning,
        secondaryGlow: AppColors.danger,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: GlassIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
              ),
              const Spacer(),
              IconBadge(
                icon: Icons.help_rounded,
                color: urgent ? AppColors.danger : AppColors.warning,
                size: 72,
              ),
              const SizedBox(height: Gap.lg),
              Text('Tout va bien ?', style: t.headlineMedium),
              const SizedBox(height: Gap.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
                child: Text(
                  urgent
                      ? 'Sans réponse, vos proches seront alertés dans quelques instants.'
                      : 'Votre trajet${trip == null ? '' : ' vers ${trip.destinationLabel}'} '
                            'prend plus de temps que prévu. Confirmez avec votre code.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              if (_sending)
                const Padding(
                  padding: EdgeInsets.all(Gap.xxl),
                  child: CircularProgressIndicator(),
                )
              else
                CodeKeypad(
                  title: 'Votre code',
                  subtitle: _error ?? 'Code de désarmement',
                  onSubmit: _submit,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.xs,
                  Gap.page,
                  Gap.md,
                ),
                child: AppButton.danger(
                  label: 'Non, j’ai besoin d’aide',
                  icon: Icons.sos_rounded,
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.sos),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
