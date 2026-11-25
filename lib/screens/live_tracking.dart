import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/repositories/contacts_repository.dart';
import '../data/repositories/location_repository.dart';
import '../services/inbox_service.dart';
import 'map.dart' show darkMapStyle;

/// Suivi en direct d'une personne protégée pendant son SOS.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key, required this.args});

  final LiveTrackingArgs args;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _trail = <LivePoint>[];
  GoogleMapController? _map;
  RealtimeChannel? _channel;
  StreamSubscription<SosClosed>? _closedSub;
  bool _loading = true;
  bool _accessEnded = false;
  late bool _silent = widget.args.silent;

  String get _userId => widget.args.userId;

  String get _name {
    if (widget.args.name != null) return widget.args.name!;
    final p = ContactsRepository.instance.protectedPeople.value.where(
      (p) => p.userId == _userId,
    );
    return p.isEmpty ? 'Votre proche' : p.first.name;
  }

  String? get _phone {
    final p = ContactsRepository.instance.protectedPeople.value.where(
      (p) => p.userId == _userId,
    );
    return p.isEmpty ? null : p.first.phone;
  }

  @override
  void initState() {
    super.initState();
    InboxService.instance.openTrackingFor = _userId;
    HapticFeedback.heavyImpact();
    _closedSub = InboxService.instance.sosClosed
        .where((e) => e.userId == _userId)
        .listen(_onClosed);
    _load();
  }

  @override
  void dispose() {
    if (InboxService.instance.openTrackingFor == _userId) {
      InboxService.instance.openTrackingFor = null;
    }
    _closedSub?.cancel();
    final c = _channel;
    if (c != null) Backend.client.removeChannel(c);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await LocationRepository.instance.liveLocation(_userId);
      if (!mounted) return;
      if (live == null) {
        setState(() {
          _loading = false;
          _accessEnded = true;
        });
        return;
      }
      setState(() {
        _loading = false;
        _silent = _silent || live.silent;
        _trail
          ..clear()
          ..addAll(live.trail);
      });
      _focus();
      _channel = await LocationRepository.instance.subscribePositions(
        _userId,
        _onPoint,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  void _onPoint(LivePoint p) {
    if (!mounted) return;
    setState(() => _trail.add(p));
    _focus();
  }

  void _focus() {
    final last = _trail.isEmpty ? null : _trail.last;
    if (last == null) return;
    _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(last.lat, last.lng), 16.5),
    );
  }

  Future<void> _onClosed(SosClosed e) async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          e.outcome == 'cancelled'
              ? Icons.info_outline_rounded
              : Icons.verified_user_rounded,
          color: e.outcome == 'cancelled' ? AppColors.info : AppColors.success,
          size: 40,
        ),
        title: Text(
          e.outcome == 'cancelled' ? 'Fausse alerte' : '$_name est en sécurité',
        ),
        content: Text(
          e.outcome == 'cancelled'
              ? '$_name a indiqué que l’alerte était une erreur.'
              : 'L’alerte est terminée. Le suivi de position s’arrête.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = _trail.isEmpty ? null : _trail.last;
    final target = last == null
        ? const LatLng(14.7167, -17.4677)
        : LatLng(last.lat, last.lng);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: target, zoom: 15),
              style: darkMapStyle,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              padding: const EdgeInsets.only(top: 160, bottom: 240),
              onMapCreated: (c) {
                _map = c;
                _focus();
              },
              polylines: {
                if (_trail.length > 1)
                  Polyline(
                    polylineId: const PolylineId('trail'),
                    color: AppColors.danger,
                    width: 4,
                    points: [for (final p in _trail) LatLng(p.lat, p.lng)],
                  ),
              },
              markers: {
                if (last != null)
                  Marker(
                    markerId: const MarkerId('last'),
                    position: target,
                    infoWindow: InfoWindow(
                      title: _name,
                      snippet: 'À ${clockWithSeconds(last.time)}',
                    ),
                  ),
              },
              circles: {
                if (last != null)
                  Circle(
                    circleId: const CircleId('acc'),
                    center: target,
                    radius: last.accuracy.clamp(10, 200),
                    fillColor: AppColors.danger.withValues(alpha: 0.12),
                    strokeColor: AppColors.danger.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
              },
            ),
          ),

          // Bandeau supérieur
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      const StatusPill(
                        label: 'En direct',
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  AppCard(
                    gradient: _silent ? null : AppColors.dangerGradient,
                    color: AppColors.surface,
                    borderColor: _silent
                        ? AppColors.warning.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.2),
                    glow: AppColors.danger,
                    child: Row(
                      children: [
                        Icon(
                          _silent
                              ? Icons.do_not_disturb_on_rounded
                              : Icons.sos_rounded,
                          color: _silent ? AppColors.warning : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _silent
                                    ? 'Alerte discrète — ne l’appelez pas'
                                    : '$_name a déclenché un SOS',
                                style: t.titleSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _silent
                                    ? '$_name est peut-être sous la contrainte. '
                                          'Un appel pourrait le·la mettre en danger.'
                                    : 'Sa position est partagée avec vous en direct.',
                                style: t.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panneau inférieur
          Positioned(
            left: Gap.page,
            right: Gap.page,
            bottom: MediaQuery.paddingOf(context).bottom + Gap.md,
            child: AppCard(
              radius: Radii.xlAll,
              color: AppColors.surface.withValues(alpha: 0.97),
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(Gap.md),
                      child: CircularProgressIndicator(),
                    )
                  else if (_accessEnded)
                    Text(
                      'Aucun partage actif : l’alerte est terminée.',
                      style: t.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const IconBadge(
                          icon: Icons.my_location_rounded,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Text(
                            last == null
                                ? 'En attente de la première position…'
                                : 'Dernière position à ${clockWithSeconds(last.time)} '
                                      '(±${last.accuracy.round()} m)',
                            style: t.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      if (!_silent && _phone != null) ...[
                        Expanded(
                          child: AppButton.secondary(
                            label: 'Appeler',
                            icon: Icons.call_rounded,
                            onPressed: () => callNumber(context, _phone!),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                      ],
                      Expanded(
                        child: AppButton.danger(
                          label: 'Police (17)',
                          icon: Icons.local_police_rounded,
                          onPressed: () => callNumber(context, '17'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
