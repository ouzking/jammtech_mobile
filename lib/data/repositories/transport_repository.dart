import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../services/location_service.dart';
import '../backend.dart';
import '../models.dart';
import 'location_repository.dart' show LivePoint;

/// Vue d'un trajet suivi par un proche (`get_trip_live`).
class LiveTrip {
  const LiveTrip({
    required this.trip,
    required this.travelerName,
    required this.trail,
    this.lateMinutes = 0,
    this.battery,
  });

  final Trip trip;
  final String travelerName;
  final List<LivePoint> trail;
  final int lateMinutes;
  final int? battery;
}

/// Pilier Transport : trajet sécurisé (voyageur et proche).
///
/// Règle du backend : **le serveur décide de l'escalade**. L'application ne
/// déclenche jamais de SOS à cause d'un retard ; elle se contente d'envoyer sa
/// position et de répondre aux « Tout va bien ? ».
class TransportRepository {
  TransportRepository._();
  static final instance = TransportRepository._();

  final summary = ValueNotifier<TransportSummary?>(null);

  Trip? get activeTrip => summary.value?.activeTrip;

  Future<TransportSummary> refresh() async {
    if (!Backend.enabled) {
      return summary.value ??= const TransportSummary();
    }
    try {
      final r = await Backend.rpc<Map<String, dynamic>>(
        'get_transport_summary',
      );
      final s = TransportSummary.fromJson(r);
      summary.value = s;
      // Le flux de position suit l'état réel du trajet côté serveur.
      s.activeTrip != null
          ? LocationService.instance.start(TrackingReason.trip)
          : LocationService.instance.stop(TrackingReason.trip);
      return s;
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Démarre un trajet. La `client_key` est créée une seule fois puis
  /// réutilisée à chaque nouvel essai réseau (aucun doublon chez les proches).
  Future<Trip> start({
    required TripMode mode,
    required String destinationLabel,
    required double destLat,
    required double destLng,
    required DateTime expectedArrival,
    List<String>? watcherIds,
    String? plate,
    String? note,
    double? lat,
    double? lng,
    double? accuracy,
    bool night = false,
  }) async {
    final clientKey = const Uuid().v4();
    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final t = Trip(
        id: 'demo-trip',
        status: TripStatus.active,
        mode: mode,
        destinationLabel: destinationLabel,
        expectedArrival: expectedArrival,
        startedAt: DateTime.now(),
        vehiclePlate: plate,
      );
      summary.value = TransportSummary(activeTrip: t);
      return t;
    }

    final body = {
      'client_key': clientKey,
      'mode': mode.name,
      'destination': {
        'lat': destLat,
        'lng': destLng,
        'label': destinationLabel,
      },
      'expected_arrival_at': expectedArrival.toUtc().toIso8601String(),
      // De nuit, questions plus rapprochées.
      'checkin_first_minutes': night ? 2 : 3,
      'checkin_second_minutes': night ? 1 : 2,
      'watcher_contact_ids': ?watcherIds,
      if (plate != null && plate.isNotEmpty) 'vehicle_plate': plate,
      if (note != null && note.isNotEmpty) 'vehicle_note': note,
      if (lat != null && lng != null)
        'position': {'lat': lat, 'lng': lng, 'accuracy_m': ?accuracy},
    };

    var delay = const Duration(seconds: 1);
    for (var attempt = 1; ; attempt++) {
      try {
        final r = await Backend.invoke('trip-start', body: body);
        final trip = Trip.fromJson((r['trip'] as Map).cast<String, dynamic>());
        await LocationService.instance.start(TrackingReason.trip);
        refresh().ignore();
        return trip;
      } catch (e) {
        final err = toAppException(e);
        final s = err.status;
        final retryable = err.network || s == null || s >= 500 || s == 408;
        if (!retryable || attempt >= 6) throw err;
        await Future<void>.delayed(delay);
        if (delay.inSeconds < 8) delay *= 2;
      }
    }
  }

  /// Photo du véhicule, envoyée après le démarrage (facultative).
  Future<void> attachVehiclePhoto(String tripId, Uint8List jpeg) async {
    if (!Backend.enabled) return;
    final path = '${Backend.uid}/$tripId.jpg';
    try {
      await Backend.client.storage
          .from('vehicle-photos')
          .uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      await Backend.rpc<dynamic>('set_trip_vehicle', {
        'p_trip_id': tripId,
        'p_photo_path': path,
      });
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// « Tout va bien ? ».
  ///
  /// ⚠️ Code de contrainte : réponse identique au code normal. L'appelant ne
  /// doit rien faire de différent ; la position est envoyée à chaque fois.
  Future<void> checkin(
    String tripId,
    String code, {
    double? lat,
    double? lng,
  }) async {
    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (code != '1234' && code != '9999') {
        throw const AppException(
          'Code incorrect',
          code: 'invalid_code',
          status: 401,
        );
      }
      return;
    }
    try {
      await Backend.invoke(
        'trip-checkin',
        body: {'trip_id': tripId, 'code': code, 'lat': ?lat, 'lng': ?lng},
      );
      refresh().ignore();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> extend(String tripId, int minutes) async {
    if (!Backend.enabled) return;
    try {
      await Backend.rpc<dynamic>('trip_extend', {
        'p_trip_id': tripId,
        'p_minutes': minutes,
      });
      await refresh();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> arrive(String tripId) => _end('trip-arrive', tripId);

  Future<void> cancel(String tripId) => _end('trip-cancel', tripId);

  Future<void> _end(String fn, String tripId) async {
    if (Backend.enabled) {
      try {
        await Backend.invoke(fn, body: {'trip_id': tripId});
      } catch (e) {
        throw toAppException(e);
      }
    }
    LocationService.instance.stop(TrackingReason.trip);
    if (!Backend.enabled) {
      summary.value = const TransportSummary();
      return;
    }
    await refresh();
  }

  Future<void> reportBatteryLow(
    String tripId,
    int level, {
    double? lat,
    double? lng,
  }) async {
    if (!Backend.enabled) return;
    try {
      await Backend.rpc<dynamic>('trip_battery_low', {
        'p_trip_id': tripId,
        'p_level': level,
        'p_lat': lat,
        'p_lng': lng,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('trip_battery_low : $e');
    }
  }

  // --- Côté proche ----------------------------------------------------------

  /// `null` si je ne suis pas watcher ou si le trajet est terminé.
  Future<LiveTrip?> live(String tripId) async {
    if (!Backend.enabled) return null;
    try {
      final r = await Backend.rpc<Map<String, dynamic>?>('get_trip_live', {
        'p_trip_id': tripId,
      });
      if (r == null) return null;
      final tripJson = ((r['trip'] as Map?) ?? r).cast<String, dynamic>();
      final traveler = (r['traveler'] as Map?)?.cast<String, dynamic>();
      return LiveTrip(
        trip: Trip.fromJson({
          ...tripJson,
          'vehicle_plate': r['vehicle_plate'] ?? tripJson['vehicle_plate'],
          'vehicle_photo_path':
              r['vehicle_photo_path'] ?? tripJson['vehicle_photo_path'],
        }),
        travelerName: traveler?['full_name'] as String? ?? 'Votre proche',
        lateMinutes: (r['late_minutes'] as num?)?.toInt() ?? 0,
        battery: (r['last_battery'] as num?)?.toInt(),
        trail: [
          for (final p in (r['trail'] as List? ?? const []))
            LivePoint.fromJson((p as Map).cast<String, dynamic>()),
        ],
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Positions et changements d'état du trajet, en temps réel.
  Future<RealtimeChannel?> subscribe(
    String tripId, {
    required void Function(LivePoint) onPosition,
    required void Function(Map<String, dynamic>) onStatus,
  }) async {
    if (!Backend.enabled) return null;
    await Backend.client.realtime.setAuth(
      Backend.client.auth.currentSession?.accessToken,
    );
    return Backend.client
        .channel(
          'trip:$tripId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: 'position',
          callback: (m) => onPosition(LivePoint.fromJson(broadcastBody(m))),
        )
        .onBroadcast(
          event: 'status',
          callback: (m) => onStatus(broadcastBody(m)),
        )
        .subscribe();
  }

  Future<String?> vehiclePhotoUrl(String? path) async {
    if (!Backend.enabled || path == null) return null;
    try {
      return await Backend.client.storage
          .from('vehicle-photos')
          .createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

  /// Signalements le long de l'itinéraire (conseil « plus sûr de nuit »).
  Future<({int count, bool night})> routeRisks(List<List<double>> route) async {
    if (!Backend.enabled || route.length < 2) return (count: 0, night: false);
    try {
      final r = await Backend.rpc<Map<String, dynamic>>('route_risks', {
        'p_route': route,
        'p_since_minutes': 720,
        'p_buffer_m': 300,
      });
      return (
        count: (r['count'] as num?)?.toInt() ?? 0,
        night: r['night'] == true,
      );
    } catch (_) {
      return (count: 0, night: false);
    }
  }

  void clear() => summary.value = null;
}
