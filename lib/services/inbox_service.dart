import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/backend.dart';
import '../data/repositories/transport_repository.dart';
import '../routes.dart';
import 'app_navigator.dart';

/// Événement de fin de SOS reçu par un proche.
class SosClosed {
  const SosClosed(this.userId, this.outcome);

  final String userId;

  /// `resolved` (en sécurité) ou `cancelled` (fausse alerte).
  final String outcome;
}

/// Canal privé `inbox:<mon_id>` : SOS des personnes que je protège.
class InboxService {
  InboxService._();
  static final instance = InboxService._();

  RealtimeChannel? _channel;
  final _closed = StreamController<SosClosed>.broadcast();

  /// Écouté par l'écran de suivi pour se fermer à la fin du SOS.
  Stream<SosClosed> get sosClosed => _closed.stream;

  /// Identifiant de la personne dont le suivi est déjà ouvert (évite les doublons).
  String? openTrackingFor;

  Future<void> start() async {
    final uid = Backend.uid;
    if (!Backend.enabled || uid == null || _channel != null) return;
    try {
      await Backend.client.realtime.setAuth(
        Backend.client.auth.currentSession?.accessToken,
      );
      _channel = Backend.client
          .channel(
            'inbox:$uid',
            opts: const RealtimeChannelConfig(private: true),
          )
          .onBroadcast(
            event: 'sos_started',
            callback: (m) => _onSosStarted(broadcastBody(m)),
          )
          .onBroadcast(
            event: 'trip_started',
            callback: (m) {
              final id = broadcastBody(m)['trip_id'] as String?;
              TransportRepository.instance.refresh().ignore();
              if (id != null) {
                appNavigator?.pushNamed(AppRoutes.watchTrip, arguments: id);
              }
            },
          )
          .onBroadcast(
            event: 'sos_closed',
            callback: (m) {
              final b = broadcastBody(m);
              _closed.add(
                SosClosed(
                  b['user_id'] as String? ?? '',
                  b['outcome'] as String? ?? 'resolved',
                ),
              );
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) debugPrint('Inbox : $e');
    }
  }

  void _onSosStarted(Map<String, dynamic> b) {
    openLiveTracking(
      userId: b['user_id'] as String,
      silent: b['silent'] == true,
    );
  }

  /// Ouvre l'écran de suivi en direct (depuis le temps réel ou un push).
  void openLiveTracking({
    required String userId,
    bool silent = false,
    String? name,
  }) {
    if (openTrackingFor == userId) return;
    appNavigator?.pushNamed(
      AppRoutes.liveTracking,
      arguments: LiveTrackingArgs(userId: userId, silent: silent, name: name),
    );
  }

  /// Relaie un `sos_closed` reçu par push.
  void notifyClosed(String userId, String outcome) =>
      _closed.add(SosClosed(userId, outcome));

  Future<void> stop() async {
    final c = _channel;
    _channel = null;
    if (c != null) await Backend.client.removeChannel(c);
  }
}

class LiveTrackingArgs {
  const LiveTrackingArgs({
    required this.userId,
    this.silent = false,
    this.name,
  });

  final String userId;
  final bool silent;
  final String? name;
}
