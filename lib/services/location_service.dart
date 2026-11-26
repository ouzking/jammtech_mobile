import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../data/backend.dart';

/// Raisons pour lesquelles la position est envoyée au serveur.
enum TrackingReason { sos, share, silent, trip }

/// Flux GPS unique qui alimente `push_location` tant qu'au moins une raison est active.
///
/// Le serveur ignore les points quand aucun partage ni SOS n'est actif : l'envoi
/// est donc fait **sans condition** dès qu'une raison est active (règle du suivi
/// discret : un envoi conditionnel pourrait trahir la contrainte).
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  static const _silentMaxDuration = Duration(hours: 2);

  final _reasons = <TrackingReason>{};
  StreamSubscription<Position>? _sub;
  Timer? _silentTimer;

  /// Dernière position connue (utilisée par la carte et le désarmement).
  final lastPosition = ValueNotifier<Position?>(null);

  bool get isActive => _reasons.isNotEmpty;
  bool isTracking(TrackingReason r) => _reasons.contains(r);

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Position actuelle (avec demande d'autorisation si nécessaire).
  Future<Position?> currentPosition() async {
    if (!await _ensurePermission()) return null;
    final p = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    lastPosition.value = p;
    return p;
  }

  Future<void> start(TrackingReason reason) async {
    _reasons.add(reason);
    if (reason == TrackingReason.silent) {
      _silentTimer?.cancel();
      _silentTimer = Timer(
        _silentMaxDuration,
        () => stop(TrackingReason.silent),
      );
    }
    if (_sub != null) return;
    try {
      if (!await _ensurePermission()) return;
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (e) {
      if (kDebugMode) debugPrint('LocationService.start : $e');
    }
  }

  void stop(TrackingReason reason) {
    _reasons.remove(reason);
    if (reason == TrackingReason.silent) _silentTimer?.cancel();
    if (_reasons.isEmpty) {
      _sub?.cancel();
      _sub = null;
    }
  }

  /// Fin du suivi discret au prochain désarmement normal (voir brief backend).
  void stopAll() {
    for (final r in [..._reasons]) {
      stop(r);
    }
  }

  void _onPosition(Position p) {
    lastPosition.value = p;
    if (_reasons.isEmpty) return;
    push(p);
  }

  /// Envoie un point au serveur. Les erreurs sont silencieuses (réessai au point suivant).
  Future<void> push(Position p) async {
    if (!Backend.enabled || Backend.uid == null) return;
    try {
      await Backend.rpc<dynamic>('push_location', {
        'p_lat': p.latitude,
        'p_lng': p.longitude,
        'p_accuracy_m': p.accuracy,
        'p_recorded_at': p.timestamp.toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
}
