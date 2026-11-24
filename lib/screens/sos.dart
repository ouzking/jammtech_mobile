import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import 'emergency_sheets.dart';

enum _SosState { idle, countdown, sent }

/// Écran SOS : maintien de 3 s (anti-déclenchement accidentel),
/// compte à rebours annulable de 5 s, puis confirmation d'envoi.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);
  static const _countdownFrom = 5;

  late final _hold = AnimationController(vsync: this, duration: _holdDuration)
    ..addListener(_onHoldTick)
    ..addStatusListener(_onHoldStatus);
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  _SosState _state = _SosState.idle;
  int _countdown = _countdownFrom;
  int _lastHapticStep = 0;
  Timer? _timer;
  DateTime? _sentAt;

  @override
  void dispose() {
    _timer?.cancel();
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onHoldTick() {
    // Un retour haptique par seconde maintenue.
    final step = (_hold.value * 3).floor();
    if (step > _lastHapticStep) {
      _lastHapticStep = step;
      HapticFeedback.mediumImpact();
    }
  }

  void _onHoldStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _startCountdown();
  }

  void _startHold() {
    if (_state != _SosState.idle) return;
    _lastHapticStep = 0;
    HapticFeedback.lightImpact();
    _hold.forward(from: _hold.value);
  }

  void _releaseHold() {
    if (_state != _SosState.idle || _hold.isCompleted) return;
    _hold.animateBack(0, duration: Motion.medium, curve: Curves.easeOut);
  }

  void _startCountdown() {
    HapticFeedback.heavyImpact();
    setState(() {
      _state = _SosState.countdown;
      _countdown = _countdownFrom;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_countdown <= 1) {
        t.cancel();
        _send();
      } else {
        HapticFeedback.selectionClick();
        setState(() => _countdown--);
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    _hold.value = 0;
    HapticFeedback.lightImpact();
    setState(() => _state = _SosState.idle);
    showAppSnack(
      context,
      'Alerte annulée',
      icon: Icons.info_outline_rounded,
      color: AppColors.info,
    );
  }

  void _send() {
    // TODO: envoyer l'alerte (position + contacts) au backend.
    HapticFeedback.heavyImpact();
    setState(() {
      _state = _SosState.sent;
      _sentAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = _state != _SosState.idle;

    return Scaffold(
      body: AppBackground(
        glow: AppColors.danger,
        secondaryGlow: AppColors.danger,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Fermer',
                      onPressed: _state == _SosState.countdown
                          ? null
                          : () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: switch (_state) {
                        _SosState.idle => 'Prêt',
                        _SosState.countdown => 'Envoi imminent',
                        _SosState.sent => 'Alerte envoyée',
                      },
                      color: switch (_state) {
                        _SosState.idle => AppColors.success,
                        _SosState.countdown => AppColors.warning,
                        _SosState.sent => AppColors.danger,
                      },
                    ),
                    const Spacer(),
                    GlassIconButton(
                      icon: Icons.call_rounded,
                      tooltip: 'Numéros d’urgence',
                      onPressed: () => showEmergencyNumbersSheet(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.slow,
                  switchInCurve: Motion.emphasized,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: _state == _SosState.sent
                      ? _SentView(
                          key: const ValueKey('sent'),
                          sentAt: _sentAt!,
                          onSafe: () => Navigator.maybePop(context),
                        )
                      : Column(
                          key: const ValueKey('arm'),
                          children: [
                            const Spacer(),
                            Text(
                              active ? 'Envoi dans' : 'Alerte SOS',
                              style: t.headlineMedium,
                            ),
                            const SizedBox(height: Gap.xs),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Gap.xxl,
                              ),
                              child: Text(
                                active
                                    ? 'Vos proches et votre position seront transmis.'
                                    : 'Maintenez le bouton 3 secondes pour alerter vos proches.',
                                textAlign: TextAlign.center,
                                style: t.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            _SosButton(
                              hold: _hold,
                              pulse: _pulse,
                              countdown: active ? _countdown : null,
                              onHoldStart: _startHold,
                              onHoldEnd: _releaseHold,
                            ),
                            const Spacer(flex: 2),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Gap.page,
                                0,
                                Gap.page,
                                Gap.lg,
                              ),
                              child: AnimatedSwitcher(
                                duration: Motion.medium,
                                child: active
                                    ? AppButton.secondary(
                                        key: const ValueKey('cancel'),
                                        label: 'Annuler l’alerte',
                                        icon: Icons.close_rounded,
                                        onPressed: _cancel,
                                      )
                                    : const _QuickCallRow(
                                        key: ValueKey('calls'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({
    required this.hold,
    required this.pulse,
    required this.countdown,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final AnimationController hold;
  final AnimationController pulse;
  final int? countdown;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  static const _size = 210.0;
  static const _outer = 300.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Bouton SOS. Maintenir trois secondes pour envoyer une alerte.',
      // Événements bruts : pas d'arène de gestes qui annulerait le maintien.
      child: Listener(
        onPointerDown: (_) => onHoldStart(),
        onPointerUp: (_) => onHoldEnd(),
        onPointerCancel: (_) => onHoldEnd(),
        child: SizedBox(
          width: _outer,
          height: _outer,
          child: AnimatedBuilder(
            animation: Listenable.merge([hold, pulse]),
            builder: (context, _) {
              final h = Curves.easeOut.transform(hold.value);
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ondes
                  for (final o in [0.0, 0.33, 0.66])
                    Builder(
                      builder: (_) {
                        final v = (pulse.value + o) % 1;
                        final s = _size + (_outer - _size) * v;
                        return Container(
                          width: s,
                          height: s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.danger.withValues(
                                alpha: 0.35 * (1 - v),
                              ),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                  // Anneau de progression
                  SizedBox(
                    width: _size + 22,
                    height: _size + 22,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: countdown != null ? 1 : hold.value,
                      ),
                    ),
                  ),
                  // Bouton
                  Transform.scale(
                    scale: 1 - 0.05 * h,
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          radius: 1.0,
                          colors: [
                            Color(0xFFFF6B85),
                            AppColors.danger,
                            AppColors.dangerDeep,
                          ],
                          stops: [0, 0.55, 1],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(
                              alpha: 0.45 + 0.3 * h,
                            ),
                            blurRadius: 50 + 30 * h,
                            spreadRadius: 2 + 8 * h,
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: Motion.fast,
                          transitionBuilder: (c, a) =>
                              ScaleTransition(scale: a, child: c),
                          child: countdown != null
                              ? Text(
                                  '$countdown',
                                  key: ValueKey(countdown),
                                  style: t.displaySmall?.copyWith(
                                    fontSize: 72,
                                    color: Colors.white,
                                  ),
                                )
                              : Column(
                                  key: const ValueKey('label'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'SOS',
                                      style: t.displaySmall?.copyWith(
                                        color: Colors.white,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hold.value > 0
                                          ? 'Maintenez…'
                                          : 'Appui long',
                                      style: t.labelMedium?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect.deflate(2), 0, math.pi * 2, false, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _QuickCallRow extends StatelessWidget {
  const _QuickCallRow({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final numbers = DemoData.emergencyNumbers.take(3);
    return Column(
      children: [
        Text(
          'OU APPELEZ DIRECTEMENT',
          style: t.labelSmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            for (final n in numbers) ...[
              Expanded(
                child: AppCard(
                  onTap: () => callNumber(context, n.number),
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  color: AppColors.surfaceHigh,
                  child: Column(
                    children: [
                      Icon(n.icon, color: n.color, size: 22),
                      const SizedBox(height: 4),
                      Text(n.number, style: t.titleMedium),
                      Text(
                        n.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (n != numbers.last) const SizedBox(width: Gap.xs),
            ],
          ],
        ),
      ],
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({super.key, required this.sentAt, required this.onSafe});

  final DateTime sentAt;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xl, Gap.page, Gap.lg),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.dangerGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.5),
                  blurRadius: 40,
                ),
              ],
            ),
            child: const Icon(
              Icons.campaign_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text(
          'Alerte envoyée',
          textAlign: TextAlign.center,
          style: t.headlineMedium,
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'À ${clock(sentAt)} · Restez dans un lieu sûr si possible.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Gap.xl),
        AppCard(
          child: Row(
            children: [
              const IconBadge(
                icon: Icons.my_location_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Position partagée', style: t.titleSmall),
                    Text(
                      'Mise à jour en continu',
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusPill(label: 'En direct'),
            ],
          ),
        ),
        const GroupLabel('Proches prévenus'),
        SettingsGroup(
          children: [
            for (final c in DemoData.contacts)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ContactAvatar(contact: c, size: 38),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: t.titleSmall),
                          Text(
                            c.relation,
                            style: t.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.done_all_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: Gap.xl),
        AppButton.danger(
          label: 'Appeler la police (17)',
          icon: Icons.local_police_rounded,
          onPressed: () => callNumber(context, '17'),
        ),
        const SizedBox(height: Gap.sm),
        AppButton.secondary(
          label: 'Je suis en sécurité',
          icon: Icons.verified_user_rounded,
          onPressed: onSafe,
        ),
      ],
    );
  }
}
