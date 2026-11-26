import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/backend.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/transport_repository.dart';
import '../routes.dart';
import 'app_navigator.dart';
import 'inbox_service.dart';
import 'location_service.dart';

/// Push de données uniquement, reçu en arrière-plan (isolate séparé).
///
/// `silent_tracking` : envoi de la position **sans aucun affichage**.
/// Limite Android : sans service de premier plan (qui afficherait une
/// notification), l'envoi continu n'est garanti que tant que l'app est en vie ;
/// ici on transmet au moins la position courante, immédiatement.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'silent_tracking') return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await Backend.init();
    final p = await LocationService.instance.currentPosition();
    if (p != null) await LocationService.instance.push(p);
  } catch (_) {
    // Jamais d'erreur visible.
  }
}

/// Notifications push (Firebase Cloud Messaging) et canaux Android.
class PushService {
  PushService._();
  static final instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? token;

  bool get available => _ready;

  static const _channels = [
    AndroidNotificationChannel(
      'sos',
      'SOS',
      description: 'Alerte SOS d’un proche et alertes discrètes',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      'critical',
      'Alertes critiques',
      description: 'Intrusion, sabotage',
      importance: Importance.high,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'alerts',
      'Alertes',
      description: 'Zones à risque, appareils, mises à jour',
      importance: Importance.defaultImportance,
    ),
  ];

  /// À appeler au démarrage. Sans configuration Firebase, le push est
  /// simplement désactivé : le reste de l'app fonctionne.
  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push désactivé (Firebase non configuré) : $e');
      }
      return;
    }
    _ready = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) => _route(_decode(r.payload)),
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final c in _channels) {
      await android?.createNotificationChannel(c);
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _route(initial.data));
    }
    // Token initial et renouvellements.
    FirebaseMessaging.instance.onRegistered.listen(_register);
  }

  /// Après connexion : autorisation, puis enregistrement du token.
  Future<void> registerForUser() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await FirebaseMessaging.instance.register();
      if (token != null) await _register(token!);
    } catch (e) {
      if (kDebugMode) debugPrint('Token push : $e');
    }
  }

  Future<void> _register(String t) async {
    token = t;
    await AccountRepository.instance.registerPushToken(
      t,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceLabel: Platform.isIOS ? 'iPhone' : 'Android',
    );
  }

  void _onForeground(RemoteMessage m) {
    final data = m.data;
    switch (data['type']) {
      case 'silent_tracking':
        // Rien à l'écran : ni notification, ni bannière, ni icône.
        LocationService.instance.start(TrackingReason.silent);
        return;
      case 'sos':
      case 'sos_silent':
      case 'sos_closed':
      case 'trip_checkin':
        // Le suivi en direct / la question s'ouvrent immédiatement.
        _route(data);
        return;
    }
    // Alertes : notification locale (FCM ne l'affiche pas au premier plan).
    final n = m.notification;
    if (n == null) return;
    final channel = data['severity'] == 'critical' ? 'critical' : 'alerts';
    _local.show(
      id: m.hashCode,
      title: n.title,
      body: n.body,
      payload: Uri(
        queryParameters: data.map((k, v) => MapEntry(k, '$v')),
      ).query,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == 'critical' ? 'Alertes critiques' : 'Alertes',
          importance: channel == 'critical'
              ? Importance.high
              : Importance.defaultImportance,
        ),
      ),
    );
  }

  Map<String, dynamic> _decode(String? payload) =>
      payload == null ? const {} : Uri.splitQueryString(payload);

  void _route(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'silent_tracking':
        LocationService.instance.start(TrackingReason.silent);
      case 'sos':
      case 'sos_silent':
        final uid = data['user_id'] as String?;
        if (uid != null) {
          InboxService.instance.openLiveTracking(
            userId: uid,
            silent: data['type'] == 'sos_silent',
          );
        }
      case 'sos_closed':
        InboxService.instance.notifyClosed(
          data['user_id'] as String? ?? '',
          data['outcome'] as String? ?? 'resolved',
        );
      case 'alert':
        appNavigator?.pushNamed(AppRoutes.alerts);
      case 'trip_checkin':
        // Écran plein « Tout va bien ? » (tour 1 ou 2).
        TransportRepository.instance.refresh().whenComplete(() {
          appNavigator?.pushNamed(
            AppRoutes.tripCheckin,
            arguments: int.tryParse('${data['round'] ?? 1}') ?? 1,
          );
        }).ignore();
      case 'trip_started':
      case 'trip_late':
      case 'trip_battery_low':
        final id = data['trip_id'] as String?;
        if (id != null) {
          appNavigator?.pushNamed(AppRoutes.watchTrip, arguments: id);
        }
      case 'trip_arrived':
      case 'trip_cancelled':
        TransportRepository.instance.refresh().ignore();
    }
  }
}
