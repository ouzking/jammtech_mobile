import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/home_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../services/session.dart';
import 'app_page.dart';
import 'disarm_keypad.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  final _home = HomeRepository.instance;
  ArmMode? _pendingMode;

  String? get _homeId => AccountRepository.instance.dashboard.value?.homeId;

  ArmMode get _mode =>
      _pendingMode ??
      AccountRepository.instance.dashboard.value?.armMode ??
      ArmMode.disarmed;

  @override
  void initState() {
    super.initState();
    if (Backend.enabled) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final d = await AccountRepository.instance.refreshDashboard();
      await _home.refreshDevices(d.homeId);
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  Future<void> _setMode(ArmMode m) async {
    if (m == _mode || _pendingMode != null) return;
    if (m == ArmMode.disarmed) return _disarm();

    HapticFeedback.mediumImpact();
    setState(() => _pendingMode = m);
    try {
      final r = await _home.setArmMode(_homeId, m, clientDevice: 'Mobile');
      await AccountRepository.instance.refreshDashboard();
      if (!mounted) return;
      if (r.warnings.isEmpty) {
        showAppSnack(
          context,
          'Mode « ${m.label} » activé',
          icon: m.icon,
          color: m.color,
        );
      } else {
        _showWarnings(m, r.warnings);
      }
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => _pendingMode = null);
    }
  }

  /// Désarmement par code.
  ///
  /// ⚠️ Code de contrainte : ce chemin est **strictement identique** quel que
  /// soit le code saisi (même message, même vibration, même écran) et la
  /// position est envoyée à chaque fois. Ne jamais ajouter de condition sur
  /// la réponse du serveur.
  Future<void> _disarm() async {
    final code = await showDisarmKeypad(context);
    if (code == null || !mounted) return;

    setState(() => _pendingMode = ArmMode.disarmed);
    try {
      final pos = await _positionForDisarm();
      await _home.disarm(
        homeId: _homeId,
        code: code,
        clientDevice: 'Mobile',
        lat: pos?.$1,
        lng: pos?.$2,
        accuracy: pos?.$3,
      );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      showAppSnack(
        context,
        'Maison désarmée',
        icon: ArmMode.disarmed.icon,
        color: AppColors.textSecondary,
      );
      Session.refreshAll().ignore();
    } on AppException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => _pendingMode = null);
    }
  }

  /// Position (2 s max) ; même délai d'attente quel que soit le code saisi.
  Future<(double, double, double)?> _positionForDisarm() async {
    try {
      final p =
          await LocationService.instance.currentPosition().timeout(
            const Duration(seconds: 2),
          ) ??
          LocationService.instance.lastPosition.value;
      return p == null ? null : (p.latitude, p.longitude, p.accuracy);
    } catch (_) {
      final p = LocationService.instance.lastPosition.value;
      return p == null ? null : (p.latitude, p.longitude, p.accuracy);
    }
  }

  void _showWarnings(ArmMode m, List<ArmWarning> warnings) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(icon: m.icon, color: m.color),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'Mode « ${m.label} » activé',
                        style: t.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Text(
                  'Points à vérifier :',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Gap.sm),
                for (final w in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: AppCard(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderColor: AppColors.warning.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Icon(switch (w.code) {
                            'device_offline' => Icons.wifi_off_rounded,
                            'lock_unlocked' => Icons.lock_open_rounded,
                            _ => Icons.sensor_door_outlined,
                          }, color: AppColors.warning),
                          const SizedBox(width: Gap.sm),
                          Expanded(child: Text(w.message, style: t.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.md),
                AppButton.secondary(
                  label: 'Compris',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle(SmartDevice d) async {
    HapticFeedback.selectionClick();
    try {
      await _home.setDeviceOn(d, !d.on);
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AccountRepository.instance.dashboard,
      builder: (context, dashboard, _) => ValueListenableBuilder(
        valueListenable: _home.devices,
        builder: (context, devices, _) => AppPage(
          title: 'Ma maison',
          subtitle: dashboard?.homeName ?? 'Résidence principale',
          standalone: widget.standalone,
          onRefresh: _refresh,
          glow: _mode.color == AppColors.textSecondary
              ? AppColors.brand
              : _mode.color,
          actions: [
            GlassIconButton(
              icon: Icons.video_library_outlined,
              tooltip: 'Enregistrements',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.videoHistory),
            ),
          ],
          slivers: [
            PageSection(
              child: _ArmSelector(
                mode: _mode,
                busy: _pendingMode != null,
                onChanged: _setMode,
              ),
            ),
            const PageSection(child: _LiveCameraCard()),
            const PageSection(bottom: 0, child: SectionHeader('Appareils')),
            if (devices.isEmpty)
              PageSection(
                child: Text(
                  'Aucun appareil connecté pour l’instant.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: Gap.sm,
                  crossAxisSpacing: Gap.sm,
                  childAspectRatio: 1.15,
                  children: [
                    for (final d in devices)
                      _DeviceTile(device: d, onToggle: () => _toggle(d)),
                  ],
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
            PageSection(
              child: AppCard(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.videoHistory),
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.video_library_rounded,
                      color: AppColors.violet,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historique des enregistrements',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            'Conservés 30 jours',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArmSelector extends StatelessWidget {
  const _ArmSelector({
    required this.mode,
    required this.onChanged,
    this.busy = false,
  });

  final ArmMode mode;
  final ValueChanged<ArmMode> onChanged;
  final bool busy;

  String get _description => switch (mode) {
    ArmMode.disarmed =>
      'Les capteurs sont inactifs. Aucune alerte ne sera émise.',
    ArmMode.home =>
      'Portes et fenêtres surveillées, détecteurs intérieurs en pause.',
    ArmMode.away =>
      'Protection complète : tous les capteurs et caméras sont actifs.',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(6),
      radius: Radii.xlAll,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / ArmMode.values.length;
              return SizedBox(
                height: 64,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: Motion.medium,
                      curve: Motion.emphasized,
                      left: w * mode.index,
                      width: w,
                      top: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: Motion.medium,
                        decoration: BoxDecoration(
                          color: mode.color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: Border.all(
                            color: mode.color.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final m in ArmMode.values)
                          Expanded(
                            child: Semantics(
                              selected: m == mode,
                              button: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: busy ? null : () => onChanged(m),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      m.icon,
                                      size: 22,
                                      color: m == mode
                                          ? m.color
                                          : AppColors.textTertiary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.label,
                                      style: t.labelMedium?.copyWith(
                                        color: m == mode
                                            ? AppColors.textPrimary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.xs),
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: Text(
                _description,
                key: ValueKey(mode),
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCameraCard extends StatefulWidget {
  const _LiveCameraCard();

  @override
  State<_LiveCameraCard> createState() => _LiveCameraCardState();
}

class _LiveCameraCardState extends State<_LiveCameraCard> {
  static const _cameras = ['Entrée principale', 'Portail', 'Jardin', 'Salon'];

  late Timer _clock;
  DateTime _now = DateTime.now();
  int _camera = 0;
  DateTime? _recordingSince;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _toggleRecording() {
    HapticFeedback.mediumImpact();
    final starting = _recordingSince == null;
    setState(() => _recordingSince = starting ? DateTime.now() : null);
    showAppSnack(
      context,
      starting ? 'Enregistrement démarré' : 'Enregistrement sauvegardé',
      icon: starting
          ? Icons.fiber_manual_record_rounded
          : Icons.check_circle_rounded,
      color: starting ? AppColors.danger : AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final recording = _recordingSince != null;

    return Column(
      children: [
        ClipRRect(
          borderRadius: Radii.xlAll,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Flux simulé
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A2338), Color(0xFF070B14)],
                    ),
                  ),
                ),
                CustomPaint(painter: _ScanlinePainter()),
                Center(
                  child: Icon(
                    Icons.videocam_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                // Voile bas
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 90,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: Gap.md,
                  left: Gap.md,
                  child: _LiveBadge(recording: recording),
                ),
                Positioned(
                  top: Gap.md,
                  right: Gap.md,
                  child: Text(
                    clockWithSeconds(_now),
                    style: t.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Positioned(
                  left: Gap.md,
                  right: Gap.md,
                  bottom: Gap.md,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _cameras[_camera],
                              style: t.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              recording
                                  ? 'Enregistrement · ${duration(_now.difference(_recordingSince!))}'
                                  : '1080p · Vision nocturne',
                              style: t.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Pressable(
                        semanticLabel: recording
                            ? 'Arrêter l’enregistrement'
                            : 'Démarrer l’enregistrement',
                        onTap: _toggleRecording,
                        child: AnimatedContainer(
                          duration: Motion.medium,
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: Motion.medium,
                              curve: Motion.emphasized,
                              width: recording ? 18 : 34,
                              height: recording ? 18 : 34,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(
                                  recording ? 4 : 17,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cameras.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gap.xs),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(_cameras[i]),
              selected: i == _camera,
              onSelected: recording ? null : (_) => setState(() => _camera = i),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.recording});

  final bool recording;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_blink),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            widget.recording ? 'REC' : 'EN DIRECT',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Fines lignes horizontales évoquant un flux vidéo.
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onToggle});

  final SmartDevice device;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = device.color;
    return AppCard(
      onTap: onToggle,
      padding: const EdgeInsets.all(Gap.md),
      color: device.on ? AppColors.surfaceHigh : AppColors.surface,
      borderColor: device.on ? c.withValues(alpha: 0.35) : AppColors.border,
      glow: device.on ? c : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconBadge(
                icon: device.icon,
                color: device.on ? c : AppColors.textTertiary,
                filled: device.on,
                size: 40,
              ),
              const Spacer(),
              Transform.scale(
                scale: 0.8,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: device.on,
                  onChanged: (_) => onToggle(),
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? c
                        : AppColors.surfaceHighest,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.name, style: t.titleSmall),
              const SizedBox(height: 2),
              Text(
                device.on ? 'Activé · ${device.room}' : 'Désactivé',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(
                  color: device.on
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
