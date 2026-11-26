import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/repositories/location_repository.dart' show LivePoint;
import '../../data/repositories/transport_repository.dart';
import '../map.dart' show darkMapStyle;

/// Côté proche : suivi en direct du trajet d'une personne que je protège.
class WatchTripScreen extends StatefulWidget {
  const WatchTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<WatchTripScreen> createState() => _WatchTripScreenState();
}

class _WatchTripScreenState extends State<WatchTripScreen> {
  final _repo = TransportRepository.instance;
  final _trail = <LivePoint>[];
  LiveTrip? _live;
  String? _photoUrl;
  RealtimeChannel? _channel;
  GoogleMapController? _map;
  bool _loading = true;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) Backend.client.removeChannel(c);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await _repo.live(widget.tripId);
      if (!mounted) return;
      if (live == null) {
        setState(() {
          _loading = false;
          _ended = true;
        });
        return;
      }
      setState(() {
        _live = live;
        _loading = false;
        _trail
          ..clear()
          ..addAll(live.trail);
      });
      _focus();
      _repo.vehiclePhotoUrl(live.trip.vehiclePhotoPath).then((u) {
        if (mounted) setState(() => _photoUrl = u);
      });
      _channel = await _repo.subscribe(
        widget.tripId,
        onPosition: (p) {
          if (!mounted) return;
          setState(() => _trail.add(p));
          _focus();
        },
        onStatus: _onStatus,
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

  Future<void> _onStatus(Map<String, dynamic> s) async {
    final status = s['status'] as String?;
    if (status == null || status == 'active') {
      _load();
      return;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final name = _live?.travelerName ?? 'Votre proche';
    final (icon, color, title) = switch (status) {
      'arrived' => (
        Icons.where_to_vote_rounded,
        AppColors.success,
        '$name est bien arrivé·e',
      ),
      'cancelled' => (
        Icons.info_outline_rounded,
        AppColors.info,
        '$name a annulé le trajet',
      ),
      'escalated' => (
        Icons.sos_rounded,
        AppColors.danger,
        'Alerte : $name ne répond pas',
      ),
      _ => (Icons.info_outline_rounded, AppColors.info, 'Trajet terminé'),
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: color, size: 40),
        title: Text(title),
        content: Text(
          status == 'escalated'
              ? 'Une alerte SOS a été déclenchée. Suivez sa position et contactez les secours si besoin.'
              : 'Le suivi de position s’arrête.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted && status != 'escalated') Navigator.maybePop(context);
  }

  void _focus() {
    if (_trail.isEmpty) return;
    final p = _trail.last;
    _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.lat, p.lng), 15.5));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final live = _live;
    final trip = live?.trip;
    final last = _trail.isEmpty ? null : _trail.last;
    final target = last == null
        ? LatLng(trip?.destLat ?? 14.7167, trip?.destLng ?? -17.4677)
        : LatLng(last.lat, last.lng);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: target, zoom: 14),
              style: darkMapStyle,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              padding: const EdgeInsets.only(top: 120, bottom: 280),
              onMapCreated: (c) {
                _map = c;
                _focus();
              },
              polylines: {
                if (_trail.length > 1)
                  Polyline(
                    polylineId: const PolylineId('trail'),
                    color: AppColors.brand,
                    width: 4,
                    points: [for (final p in _trail) LatLng(p.lat, p.lng)],
                  ),
              },
              markers: {
                if (last != null)
                  Marker(markerId: const MarkerId('me'), position: target),
                if (trip?.destLat != null)
                  Marker(
                    markerId: const MarkerId('dest'),
                    position: LatLng(trip!.destLat!, trip.destLng!),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: InfoWindow(title: trip.destinationLabel),
                  ),
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Retour',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  const StatusPill(label: 'En direct'),
                ],
              ),
            ),
          ),
          Positioned(
            left: Gap.page,
            right: Gap.page,
            bottom: MediaQuery.paddingOf(context).bottom + Gap.md,
            child: AppCard(
              radius: Radii.xlAll,
              color: AppColors.surface.withValues(alpha: 0.97),
              padding: const EdgeInsets.all(Gap.lg),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ended || trip == null
                  ? Text(
                      'Ce trajet est terminé : le suivi n’est plus disponible.',
                      style: t.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconBadge(icon: trip.mode.icon),
                            const SizedBox(width: Gap.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${live!.travelerName} → ${trip.destinationLabel}',
                                    style: t.titleSmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    live.lateMinutes > 0
                                        ? 'En retard de ${live.lateMinutes} min · prévu à ${clock(trip.expectedArrival)}'
                                        : 'Arrivée prévue à ${clock(trip.expectedArrival)}',
                                    style: t.bodySmall?.copyWith(
                                      color: live.lateMinutes > 0
                                          ? AppColors.warning
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (trip.plateDisplay != null || _photoUrl != null) ...[
                          const SizedBox(height: Gap.md),
                          Row(
                            children: [
                              if (_photoUrl != null) ...[
                                ClipRRect(
                                  borderRadius: Radii.smAll,
                                  child: Image.network(
                                    _photoUrl!,
                                    width: 64,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                              ],
                              if (trip.plateDisplay != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(width: 1.5),
                                  ),
                                  child: Text(
                                    trip.plateDisplay!,
                                    style: t.labelLarge?.copyWith(
                                      color: Colors.black,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              if (trip.vehicleNote != null) ...[
                                const SizedBox(width: Gap.sm),
                                Expanded(
                                  child: Text(
                                    trip.vehicleNote!,
                                    style: t.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (live.battery != null && live.battery! <= 15) ...[
                          const SizedBox(height: Gap.sm),
                          StatusPill(
                            label: 'Batterie faible : ${live.battery} %',
                            color: AppColors.warning,
                          ),
                        ],
                        const SizedBox(height: Gap.md),
                        Text(
                          last == null
                              ? 'En attente de la première position…'
                              : 'Dernière position à ${clockWithSeconds(last.time)}',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
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
