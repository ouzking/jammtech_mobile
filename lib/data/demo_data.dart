import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'models.dart';

/// Données de démonstration, utilisées quand aucun backend n'est configuré
/// (développement de l'interface, tests). En production, les dépôts de
/// `lib/data/repositories/` lisent Supabase.
abstract final class DemoData {
  static const userName = 'Moussa Ndiaye';
  static const userPhone = '+221771234567';

  static final _now = DateTime.now();

  static Dashboard dashboard() => Dashboard(
    userId: 'demo',
    fullName: userName,
    phone: userPhone,
    armMode: ArmMode.away,
    camerasOnline: 4,
    camerasTotal: 4,
    devicesCount: 4,
    contactsCount: contacts.length,
    alertsTotal: alerts.length,
    alertsUnresolved: alerts.where((a) => !a.resolved).length,
    recentAlerts: alerts.take(3).toList(),
    protectionActive: true,
  );

  static const settings = <String, dynamic>{
    'precise_location': true,
    'background_location': false,
    'auto_share_on_sos': true,
    'videos_wifi_only': true,
    'anonymous_stats': false,
  };

  static const notificationPreferences = <String, dynamic>{
    'intrusions_push': true,
    'intrusions_sms': true,
    'zones_push': true,
    'zones_sms': false,
    'devices_push': true,
    'devices_sms': false,
    'contacts_push': true,
    'contacts_sms': false,
    'sound': true,
    'vibration': true,
    'quiet_hours_enabled': false,
    'quiet_hours_start': '22:00:00',
    'quiet_hours_end': '07:00:00',
  };

  static final alerts = <SecurityAlert>[
    SecurityAlert(
      id: 'a1',
      title: 'Intrusion détectée',
      description:
          'Mouvement détecté par la caméra de l’entrée alors que le système '
          'était armé. Un enregistrement de 42 secondes est disponible.',
      severity: AlertSeverity.critical,
      location: 'Entrée principale',
      time: _now.subtract(const Duration(minutes: 2)),
    ),
    SecurityAlert(
      id: 'a2',
      title: 'Zone à risque signalée',
      description:
          'Plusieurs signalements d’incidents ont été remontés à moins de '
          '500 m de votre position au cours de la dernière heure.',
      severity: AlertSeverity.warning,
      location: 'Plateau, Dakar',
      time: _now.subtract(const Duration(minutes: 18)),
    ),
    SecurityAlert(
      id: 'a3',
      title: 'Caméra hors ligne',
      description:
          'La caméra du jardin ne répond plus. Vérifiez son alimentation '
          'et la connexion Wi-Fi.',
      severity: AlertSeverity.info,
      location: 'Jardin',
      time: _now.subtract(const Duration(hours: 1, minutes: 5)),
    ),
    SecurityAlert(
      id: 'a4',
      title: 'Porte restée ouverte',
      description:
          'Le capteur de la porte du garage indique une ouverture depuis '
          'plus de 10 minutes.',
      severity: AlertSeverity.warning,
      location: 'Garage',
      time: _now.subtract(const Duration(hours: 5)),
      resolved: true,
    ),
    SecurityAlert(
      id: 'a5',
      title: 'Mise à jour installée',
      description:
          'Le micrologiciel de votre centrale a été mis à jour (v2.4.1). '
          'Aucune action requise.',
      severity: AlertSeverity.info,
      location: 'Centrale',
      time: _now.subtract(const Duration(days: 1, hours: 2)),
      resolved: true,
    ),
  ];

  static final videos = <VideoRecord>[
    VideoRecord(
      id: 'v1',
      title: 'Intrusion détectée',
      camera: 'Entrée principale',
      time: _now.subtract(const Duration(minutes: 2)),
      duration: const Duration(seconds: 42),
      motion: true,
    ),
    VideoRecord(
      id: 'v2',
      title: 'Livraison',
      camera: 'Portail',
      time: _now.subtract(const Duration(hours: 3, minutes: 12)),
      duration: const Duration(minutes: 1, seconds: 8),
    ),
    VideoRecord(
      id: 'v3',
      title: 'Mouvement détecté',
      camera: 'Jardin',
      time: _now.subtract(const Duration(days: 1, hours: 1)),
      duration: const Duration(seconds: 27),
      motion: true,
    ),
    VideoRecord(
      id: 'v4',
      title: 'Enregistrement manuel',
      camera: 'Salon',
      time: _now.subtract(const Duration(days: 4, hours: 6)),
      duration: const Duration(minutes: 3, seconds: 51),
    ),
  ];

  static const contacts = <TrustedContact>[
    TrustedContact(
      name: 'Awa Ndiaye',
      relation: 'Épouse',
      phone: '+221 77 000 00 01',
    ),
    TrustedContact(
      name: 'Ibrahima Fall',
      relation: 'Frère',
      phone: '+221 76 000 00 02',
    ),
    TrustedContact(
      name: 'Fatou Sarr',
      relation: 'Voisine',
      phone: '+221 78 000 00 03',
    ),
  ];

  /// Numéros d'urgence du Sénégal.
  static const emergencyNumbers = <EmergencyNumber>[
    EmergencyNumber(
      'Police',
      '17',
      Icons.local_police_rounded,
      AppColors.brand,
    ),
    EmergencyNumber(
      'Sapeurs-pompiers',
      '18',
      Icons.local_fire_department_rounded,
      AppColors.danger,
    ),
    EmergencyNumber(
      'SAMU',
      '1515',
      Icons.medical_services_rounded,
      AppColors.success,
    ),
    EmergencyNumber(
      'Gendarmerie',
      '800 00 20 20',
      Icons.shield_moon_rounded,
      AppColors.violet,
    ),
  ];

  static List<SmartDevice> devices() => [
    SmartDevice(
      name: 'Caméras',
      room: '4 actives',
      icon: Icons.videocam_rounded,
      color: AppColors.brand,
      on: true,
    ),
    SmartDevice(
      name: 'Sirène',
      room: 'Centrale',
      icon: Icons.campaign_rounded,
      color: AppColors.danger,
    ),
    SmartDevice(
      name: 'Éclairage',
      room: 'Extérieur',
      icon: Icons.lightbulb_rounded,
      color: AppColors.warning,
      on: true,
    ),
    SmartDevice(
      name: 'Serrure',
      room: 'Porte d’entrée',
      icon: Icons.lock_rounded,
      color: AppColors.success,
      on: true,
    ),
  ];
}
