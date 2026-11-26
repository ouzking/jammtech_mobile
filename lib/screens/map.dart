import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/location_repository.dart';
import '../routes.dart';
import 'emergency_sheets.dart';

enum _LocStatus { loading, live, serviceOff, denied, deniedForever, error }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.standalone = false});

  final bool standalone;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _dakar = LatLng(14.7167, -17.4677);

  GoogleMapController? _map;
  StreamSubscription<Position>? _sub;
  _LocStatus _status = _LocStatus.loading;
  Position? _position;
  bool _follow = true;
  late bool _sharing =
      AccountRepository.instance.dashboard.value?.locationSharing ?? false;
  bool _sharingBusy = false;
  List<RiskZone> _risks = const [];
  DateTime? _risksAt;

  LatLng get _latLng => _position == null
      ? _dakar
      : LatLng(_position!.latitude, _position!.longitude);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _status = _LocStatus.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _set(_LocStatus.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) return _set(_LocStatus.denied);
      if (perm == LocationPermission.deniedForever) {
        return _set(_LocStatus.deniedForever);
      }

      final first = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _onPosition(first);

      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPosition, onError: (_) => _set(_LocStatus.error));
    } catch (_) {
      _set(_LocStatus.error);
    }
  }

  void _set(_LocStatus s) {
    if (mounted) setState(() => _status = s);
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    setState(() {
      _position = p;
      _status = _LocStatus.live;
    });
    // Zones à risque : rafraîchies au plus toutes les 2 minutes.
    final now = DateTime.now();
    if (_risksAt == null || now.difference(_risksAt!).inMinutes >= 2) {
      _risksAt = now;
      LocationRepository.instance.nearbyRisks(p.latitude, p.longitude).then((
        r,
      ) {
        if (mounted) setState(() => _risks = r);
      });
    }
    if (_follow) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_latLng, 16.5));
    }
  }

  void _recenter() {
    setState(() => _follow = true);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(_latLng, 16.5));
  }

  Future<void> _toggleSharing() async {
    if (_sharingBusy) return;
    final start = !_sharing;
    setState(() => _sharingBusy = true);
    try {
      start
          ? await LocationRepository.instance.startShare()
          : await LocationRepository.instance.stopShare();
      if (!mounted) return;
      setState(() => _sharing = start);
      AccountRepository.instance.refreshDashboard().ignore();
      showAppSnack(
        context,
        start
            ? 'Position partagée avec vos proches pendant 8 h'
            : 'Partage de position arrêté',
        icon: start ? Icons.share_location_rounded : Icons.location_disabled,
        color: start ? AppColors.success : AppColors.textSecondary,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _sharingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = widget.standalone
        ? MediaQuery.paddingOf(context).bottom + Gap.md
        : 96 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _latLng, zoom: 14),
              style: darkMapStyle,
              myLocationEnabled: _status == _LocStatus.live,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              padding: EdgeInsets.only(bottom: bottomInset + 150, top: 120),
              onMapCreated: (c) => _map = c,
              onCameraMoveStarted: () {
                if (_follow) setState(() => _follow = false);
              },
              markers: {
                for (final (i, r) in _risks.indexed)
                  Marker(
                    markerId: MarkerId('risk$i'),
                    position: LatLng(r.lat, r.lng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                    infoWindow: InfoWindow(
                      title: r.label,
                      snippet: '${r.description} · à ${r.distance} m',
                    ),
                  ),
              },
              circles: {
                if (_position != null)
                  Circle(
                    circleId: const CircleId('accuracy'),
                    center: _latLng,
                    radius: _position!.accuracy.clamp(10, 200),
                    fillColor: AppColors.brand.withValues(alpha: 0.12),
                    strokeColor: AppColors.brand.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
              },
            ),
          ),

          // Dégradé haut pour la lisibilité de l'en-tête.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.background, Color(0x000A0F1E)],
                  ),
                ),
              ),
            ),
          ),

          // En-tête
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
              child: Row(
                children: [
                  if (widget.standalone) ...[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Retour',
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: Gap.sm),
                  ],
                  Expanded(
                    child: Text(
                      'Ma position',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom avant',
                    onPressed: () => _map?.animateCamera(CameraUpdate.zoomIn()),
                  ),
                  const SizedBox(width: Gap.xs),
                  GlassIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom arrière',
                    onPressed: () =>
                        _map?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                ],
              ),
            ),
          ),

          // Panneau inférieur
          Positioned(
            left: Gap.page,
            right: Gap.page,
            bottom: bottomInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedOpacity(
                      opacity: _follow ? 0 : 1,
                      duration: Motion.medium,
                      child: GlassIconButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Recentrer',
                        size: 52,
                        onPressed: _follow ? null : _recenter,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Pressable(
                      semanticLabel: 'SOS',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.sos),
                      child: Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.dangerGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withValues(alpha: 0.55),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                  ],
                ),
                const SizedBox(height: Gap.md),
                _StatusPanel(
                  status: _status,
                  position: _position,
                  sharing: _sharing,
                  onRetry: _start,
                  onToggleShare: _toggleSharing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.position,
    required this.sharing,
    required this.onRetry,
    required this.onToggleShare,
  });

  final _LocStatus status;
  final Position? position;
  final bool sharing;
  final VoidCallback onRetry;
  final VoidCallback onToggleShare;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (status) {
      _LocStatus.loading => (
        Icons.gps_not_fixed_rounded,
        AppColors.info,
        'Recherche du signal GPS…',
        'Cela ne prend que quelques secondes.',
      ),
      _LocStatus.live => (
        Icons.gps_fixed_rounded,
        AppColors.success,
        'Position en direct',
        'Précision ±${position!.accuracy.round()} m · ${clockWithSeconds(position!.timestamp.toLocal())}',
      ),
      _LocStatus.serviceOff => (
        Icons.location_off_rounded,
        AppColors.warning,
        'Localisation désactivée',
        'Activez la localisation de l’appareil pour être retrouvé.',
      ),
      _LocStatus.denied => (
        Icons.location_disabled_rounded,
        AppColors.warning,
        'Autorisation requise',
        'JammTech a besoin de votre position pour vous protéger.',
      ),
      _LocStatus.deniedForever => (
        Icons.block_rounded,
        AppColors.danger,
        'Accès bloqué',
        'Autorisez la localisation dans les réglages de l’appareil.',
      ),
      _LocStatus.error => (
        Icons.error_outline_rounded,
        AppColors.danger,
        'Position indisponible',
        'Impossible d’obtenir votre position pour le moment.',
      ),
    };

    final Widget? action = switch (status) {
      _LocStatus.live => null,
      _LocStatus.loading => null,
      _LocStatus.serviceOff => _SmallButton(
        label: 'Activer',
        onTap: () async {
          await Geolocator.openLocationSettings();
          onRetry();
        },
      ),
      _LocStatus.deniedForever => _SmallButton(
        label: 'Réglages',
        onTap: () async {
          await Geolocator.openAppSettings();
          onRetry();
        },
      ),
      _ => _SmallButton(label: 'Réessayer', onTap: onRetry),
    };

    return AppCard(
      color: AppColors.surface.withValues(alpha: 0.96),
      radius: Radii.xlAll,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        children: [
          Row(
            children: [
              status == _LocStatus.loading
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  : IconBadge(icon: icon, color: color),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          if (status == _LocStatus.live) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: _PanelAction(
                    icon: sharing
                        ? Icons.stop_circle_outlined
                        : Icons.share_location_rounded,
                    label: sharing ? 'Arrêter le partage' : 'Partager',
                    color: sharing ? AppColors.warning : AppColors.success,
                    onTap: onToggleShare,
                  ),
                ),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: _PanelAction(
                    icon: Icons.groups_rounded,
                    label: 'Mes proches',
                    color: AppColors.brandBright,
                    onTap: () => showTrustedContactsSheet(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.surfaceHigh,
      radius: Radii.mdAll,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: Gap.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Style de carte sombre assorti à la charte.
const darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0b1222"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#7a869e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0b1222"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1e2a44"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#101a30"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0e2229"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#18223a"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0b1222"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#243356"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#a3adc2"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#141e34"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#050913"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d4a66"}]}
]
''';
