import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/location_service.dart';
import '../backend.dart';

class LivePoint {
  const LivePoint(this.lat, this.lng, this.accuracy, this.time);

  factory LivePoint.fromJson(Map<String, dynamic> j) => LivePoint(
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    (j['accuracy_m'] as num?)?.toDouble() ?? 0,
    DateTime.tryParse(j['recorded_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime time;
}

class LiveLocation {
  const LiveLocation({required this.trail, this.sosId, this.silent = false});

  final List<LivePoint> trail;
  final String? sosId;
  final bool silent;

  LivePoint? get last => trail.isEmpty ? null : trail.last;
}

class RiskZone {
  const RiskZone(
    this.category,
    this.description,
    this.lat,
    this.lng,
    this.distance,
  );

  factory RiskZone.fromJson(Map<String, dynamic> j) => RiskZone(
    j['category'] as String? ?? 'other',
    j['description'] as String? ?? '',
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    (j['distance_m'] as num?)?.round() ?? 0,
  );

  final String category;
  final String description;
  final double lat;
  final double lng;
  final int distance;

  String get label => switch (category) {
    'theft' => 'Vol',
    'assault' => 'Agression',
    'suspicious' => 'Activité suspecte',
    'accident' => 'Accident',
    'fire' => 'Incendie',
    _ => 'Incident',
  };
}

/// Partage de position, suivi d'une personne protégée, zones à risque.
class LocationRepository {
  LocationRepository._();
  static final instance = LocationRepository._();

  Future<void> startShare({int minutes = 480}) async {
    if (Backend.enabled) {
      try {
        await Backend.rpc<dynamic>('start_location_share', {
          'p_duration_minutes': minutes,
        });
      } catch (e) {
        throw toAppException(e);
      }
    }
    await LocationService.instance.start(TrackingReason.share);
  }

  Future<void> stopShare() async {
    LocationService.instance.stop(TrackingReason.share);
    if (!Backend.enabled) return;
    try {
      await Backend.rpc<dynamic>('stop_location_share');
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// `null` si aucun partage ni SOS n'est actif (l'accès est alors refusé).
  Future<LiveLocation?> liveLocation(String userId) async {
    if (!Backend.enabled) return null;
    try {
      final r = await Backend.rpc<Map<String, dynamic>?>('get_live_location', {
        'p_user_id': userId,
        'p_trail_minutes': 30,
      });
      if (r == null) return null;
      final sos = r['sos'] as Map?;
      return LiveLocation(
        trail: [
          for (final p in (r['trail'] as List? ?? const []))
            LivePoint.fromJson((p as Map).cast<String, dynamic>()),
        ],
        sosId: sos?['id'] as String?,
        silent: sos?['silent'] == true,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Abonnement temps réel aux positions d'une personne protégée.
  Future<RealtimeChannel?> subscribePositions(
    String userId,
    void Function(LivePoint) onPoint,
  ) async {
    if (!Backend.enabled) return null;
    await Backend.client.realtime.setAuth(
      Backend.client.auth.currentSession?.accessToken,
    );
    return Backend.client
        .channel(
          'location:$userId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: 'position',
          callback: (p) => onPoint(LivePoint.fromJson(broadcastBody(p))),
        )
        .subscribe();
  }

  Future<List<RiskZone>> nearbyRisks(double lat, double lng) async {
    if (!Backend.enabled) return const [];
    try {
      final rows = await Backend.rpc<List<dynamic>>('nearby_risks', {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_m': 500,
        'p_since_minutes': 60,
      });
      return [
        for (final r in rows)
          RiskZone.fromJson((r as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }
}
