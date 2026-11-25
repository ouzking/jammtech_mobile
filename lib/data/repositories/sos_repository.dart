import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../services/location_service.dart';
import '../backend.dart';

/// Résultat d'un envoi de SOS.
class SosResult {
  const SosResult({
    required this.eventId,
    required this.startedAt,
    this.pushSent = 0,
    this.smsSent = 0,
    this.failed = 0,
    this.locationShared = false,
    this.created = true,
  });

  final String? eventId;
  final DateTime startedAt;
  final int pushSent;
  final int smsSent;
  final int failed;
  final bool locationShared;

  /// `false` quand un nouvel essai retrouve un SOS déjà créé : les proches
  /// ont alors été prévenus lors du premier envoi (compteurs à zéro ici).
  final bool created;
}

/// Déclenchement et clôture du SOS.
///
/// Règles du backend :
/// - la `client_key` (UUID v4) est créée **une seule fois**, à la confirmation,
///   et réutilisée pour chaque nouvel essai réseau → aucun doublon chez les proches ;
/// - nouvel essai automatique (1 s, 2 s, 4 s, puis toutes les 8 s) ;
/// - le SOS n'attend jamais le GPS plus de 2 s.
class SosRepository {
  SosRepository._();
  static final instance = SosRepository._();

  /// Nombre d'essais déjà faits pour le SOS en cours (affiché à l'écran).
  final attempts = ValueNotifier<int>(0);

  bool _cancelled = false;

  Future<SosResult> trigger() async {
    _cancelled = false;
    attempts.value = 0;
    final clientKey = const Uuid().v4();
    final position = await _quickPosition();

    // Le flux de position démarre tout de suite : le serveur ignore les points
    // tant que le SOS n'est pas créé, puis les rattache à l'événement.
    LocationService.instance.start(TrackingReason.sos);

    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return SosResult(
        eventId: null,
        startedAt: DateTime.now(),
        pushSent: 3,
        smsSent: 3,
      );
    }

    var delay = const Duration(seconds: 1);
    while (true) {
      attempts.value++;
      try {
        final r = await Backend.invoke(
          'sos-trigger',
          body: {
            'client_key': clientKey,
            if (position != null) ...{
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy_m': position.accuracy,
            },
          },
        );
        final n = (r['notified'] as Map?) ?? const {};
        int c(Object? v) => (v as num?)?.toInt() ?? 0;
        return SosResult(
          eventId: r['sos_event_id'] as String?,
          startedAt:
              DateTime.tryParse(r['started_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
          pushSent: c(n['push']),
          smsSent: c(n['sms']),
          failed: c(n['failed']),
          locationShared: r['location_shared'] == true,
          created: r['created'] != false,
        );
      } catch (e) {
        final err = toAppException(e);
        // Erreur métier (4xx hors 408/429) : inutile de réessayer.
        final s = err.status;
        final retryable =
            err.network || s == null || s >= 500 || s == 408 || s == 429;
        if (!retryable || _cancelled) throw err;
        if (kDebugMode) debugPrint('sos-trigger : nouvel essai dans $delay');
        await Future<void>.delayed(delay);
        if (_cancelled) throw err;
        if (delay.inSeconds < 8) delay *= 2;
      }
    }
  }

  /// Arrête les nouveaux essais (écran fermé).
  void abortRetries() => _cancelled = true;

  /// « Je suis en sécurité » (`resolved`) ou fausse alerte (`cancelled`).
  Future<void> resolve({String outcome = 'resolved', String? code}) async {
    abortRetries();
    if (Backend.enabled) {
      try {
        await Backend.invoke(
          'sos-resolve',
          body: {'outcome': outcome, 'code': ?code},
        );
      } catch (e) {
        throw toAppException(e);
      }
    }
    LocationService.instance.stop(TrackingReason.sos);
  }

  /// Position en 2 s maximum, sinon la dernière connue, sinon `null`.
  Future<Position?> _quickPosition() async {
    try {
      return await LocationService.instance.currentPosition().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
