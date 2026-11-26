import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/alerts_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/contacts_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/transport_repository.dart';
import 'inbox_service.dart';
import 'location_service.dart';
import 'push_service.dart';

/// Orchestration de la session : chargement initial, temps réel, push, déconnexion.
abstract final class Session {
  static bool get hasSession => Backend.isSignedIn;

  /// Après connexion ou vérification OTP (et au démarrage si déjà connecté).
  static Future<void> onSignedIn() async {
    InboxService.instance.start();
    PushService.instance.registerForUser();
    await refreshAll();
  }

  /// Recharge les données principales en parallèle.
  static Future<void> refreshAll() async {
    try {
      final d = await AccountRepository.instance.refreshDashboard();
      await Future.wait([
        AlertsRepository.instance.refresh(),
        ContactsRepository.instance.refresh(),
        HomeRepository.instance.refreshDevices(d.homeId),
        ContactsRepository.instance.refreshProtected(activeSos: d.protectedSos),
        TransportRepository.instance.refresh(),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('refreshAll : $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    LocationService.instance.stopAll();
    await InboxService.instance.stop();
    await AuthRepository.instance.signOut(
      pushToken: PushService.instance.token,
    );
    AccountRepository.instance.clear();
    if (Backend.enabled) {
      AlertsRepository.instance.clear();
      ContactsRepository.instance.clear();
      HomeRepository.instance.clear();
      TransportRepository.instance.clear();
    }
  }
}
