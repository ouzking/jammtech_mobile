import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

DateTime _date(Object? v) =>
    v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

enum AlertSeverity {
  critical('Critique', AppColors.danger, Icons.gpp_maybe_rounded),
  warning('Avertissement', AppColors.warning, Icons.warning_amber_rounded),
  info('Information', AppColors.info, Icons.info_outline_rounded);

  const AlertSeverity(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class SecurityAlert {
  SecurityAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.location,
    required this.time,
    this.resolved = false,
    this.recordingId,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> j) => SecurityAlert(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    severity: _enum(AlertSeverity.values, j['severity'], AlertSeverity.info),
    location: j['location_label'] as String? ?? '',
    time: _date(j['created_at']),
    // get_dashboard renvoie `resolved`, la table renvoie `resolved_at`.
    resolved: j['resolved'] as bool? ?? j['resolved_at'] != null,
    recordingId: j['recording_id'] as String?,
  );

  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final String location;
  final DateTime time;
  final String? recordingId;
  bool resolved;
}

class VideoRecord {
  const VideoRecord({
    required this.id,
    required this.title,
    required this.camera,
    required this.time,
    required this.duration,
    this.motion = false,
    this.storagePath,
    this.thumbnailPath,
  });

  factory VideoRecord.fromJson(Map<String, dynamic> j) {
    final device = j['devices'] as Map<String, dynamic>?;
    return VideoRecord(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Enregistrement',
      camera: device?['name'] as String? ?? 'Caméra',
      time: _date(j['started_at']),
      duration: Duration(
        seconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
      ),
      motion: j['motion_detected'] as bool? ?? false,
      storagePath: j['storage_path'] as String?,
      thumbnailPath: j['thumbnail_path'] as String?,
    );
  }

  final String id;
  final String title;
  final String camera;
  final DateTime time;
  final Duration duration;
  final bool motion;
  final String? storagePath;
  final String? thumbnailPath;
}

class TrustedContact {
  const TrustedContact({
    this.id = '',
    required this.name,
    required this.relation,
    required this.phone,
    this.priority = 1,
    this.hasApp = false,
  });

  factory TrustedContact.fromJson(Map<String, dynamic> j) => TrustedContact(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    relation: j['relation'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    priority: (j['priority'] as num?)?.toInt() ?? 1,
    hasApp: j['contact_user_id'] != null,
  );

  final String id;
  final String name;
  final String relation;
  final String phone;
  final int priority;

  /// Le proche a un compte vérifié : il reçoit les push et peut suivre la position.
  final bool hasApp;

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

/// Personne qui m'a désigné·e comme contact de confiance.
class ProtectedPerson {
  const ProtectedPerson({
    required this.userId,
    required this.name,
    required this.phone,
    required this.relation,
    this.inSos = false,
    this.silentSos = false,
  });

  factory ProtectedPerson.fromJson(Map<String, dynamic> j) => ProtectedPerson(
    userId: j['owner_id'] as String,
    name: j['full_name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    relation: j['relation'] as String? ?? '',
  );

  final String userId;
  final String name;
  final String phone;
  final String relation;
  final bool inSos;
  final bool silentSos;

  ProtectedPerson copyWith({bool? inSos, bool? silentSos}) => ProtectedPerson(
    userId: userId,
    name: name,
    phone: phone,
    relation: relation,
    inSos: inSos ?? this.inSos,
    silentSos: silentSos ?? this.silentSos,
  );

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

class EmergencyNumber {
  const EmergencyNumber(this.label, this.number, this.icon, this.color);

  final String label;
  final String number;
  final IconData icon;
  final Color color;
}

enum ArmMode {
  disarmed('Désarmé', Icons.lock_open_rounded, AppColors.textSecondary),
  home('Présence', Icons.home_rounded, AppColors.warning),
  away('Absence', Icons.shield_rounded, AppColors.success);

  const ArmMode(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static ArmMode parse(Object? v) => _enum(values, v, ArmMode.disarmed);
}

enum DeviceType {
  camera('Caméra', Icons.videocam_rounded, AppColors.brand),
  siren('Sirène', Icons.campaign_rounded, AppColors.danger),
  light('Éclairage', Icons.lightbulb_rounded, AppColors.warning),
  lock('Serrure', Icons.lock_rounded, AppColors.success),
  sensor('Capteur', Icons.sensors_rounded, AppColors.info);

  const DeviceType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class SmartDevice {
  SmartDevice({
    this.id = '',
    this.type = DeviceType.sensor,
    required this.name,
    required this.room,
    required this.icon,
    required this.color,
    this.on = false,
    this.online = true,
  });

  factory SmartDevice.fromJson(Map<String, dynamic> j) {
    final type = _enum(DeviceType.values, j['type'], DeviceType.sensor);
    return SmartDevice(
      id: j['id'] as String,
      type: type,
      name: j['name'] as String? ?? type.label,
      room: j['room'] as String? ?? '',
      icon: type.icon,
      color: type.color,
      on: j['is_on'] as bool? ?? false,
      online: j['is_online'] as bool? ?? true,
    );
  }

  final String id;
  final DeviceType type;
  final String name;
  final String room;
  final IconData icon;
  final Color color;
  bool on;
  bool online;
}

/// Avertissement renvoyé par `set_arm_mode` (caméra hors ligne, porte ouverte…).
class ArmWarning {
  const ArmWarning({required this.code, required this.message, this.room});

  factory ArmWarning.fromJson(Map<String, dynamic> j) => ArmWarning(
    code: j['code'] as String? ?? '',
    message: j['message'] as String? ?? '',
    room: j['room'] as String?,
  );

  final String code;
  final String message;
  final String? room;
}

/// Résumé de l'accueil (`get_dashboard`).
class Dashboard {
  const Dashboard({
    required this.userId,
    required this.fullName,
    required this.phone,
    this.avatarPath,
    this.language = 'fr',
    this.homeId,
    this.homeName = 'Résidence principale',
    this.armMode = ArmMode.disarmed,
    this.camerasOnline = 0,
    this.camerasTotal = 0,
    this.devicesCount = 0,
    this.contactsCount = 0,
    this.protectedPeopleCount = 0,
    this.alertsTotal = 0,
    this.alertsUnresolved = 0,
    this.recentAlerts = const [],
    this.activeSosId,
    this.locationSharing = false,
    this.protectedSos = const [],
    this.protectionActive = false,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final p = (j['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    final h = (j['home'] as Map?)?.cast<String, dynamic>();
    final cams = (j['cameras'] as Map?)?.cast<String, dynamic>() ?? const {};
    final alerts = (j['alerts'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return Dashboard(
      userId: p['id'] as String? ?? '',
      fullName: p['full_name'] as String? ?? '',
      phone: p['phone'] as String? ?? '',
      avatarPath: p['avatar_url'] as String?,
      language: p['language'] as String? ?? 'fr',
      homeId: h?['id'] as String?,
      homeName: h?['name'] as String? ?? 'Résidence principale',
      armMode: ArmMode.parse(h?['arm_mode']),
      camerasOnline: n(cams['online']),
      camerasTotal: n(cams['total']),
      devicesCount: n(j['devices_count']),
      contactsCount: n(j['contacts_count']),
      protectedPeopleCount: n(j['protected_people_count']),
      alertsTotal: n(alerts['total']),
      alertsUnresolved: n(alerts['unresolved']),
      recentAlerts: [
        for (final a in (j['recent_alerts'] as List? ?? const []))
          SecurityAlert.fromJson((a as Map).cast<String, dynamic>()),
      ],
      activeSosId: (j['active_sos'] as Map?)?['id'] as String?,
      locationSharing: j['location_sharing'] != null,
      protectedSos: [
        for (final s in (j['protected_sos'] as List? ?? const []))
          (s as Map).cast<String, dynamic>(),
      ],
      protectionActive: j['protection_active'] as bool? ?? false,
    );
  }

  final String userId;
  final String fullName;
  final String phone;
  final String? avatarPath;
  final String language;
  final String? homeId;
  final String homeName;
  final ArmMode armMode;
  final int camerasOnline;
  final int camerasTotal;
  final int devicesCount;
  final int contactsCount;
  final int protectedPeopleCount;
  final int alertsTotal;
  final int alertsUnresolved;
  final List<SecurityAlert> recentAlerts;
  final String? activeSosId;
  final bool locationSharing;
  final List<Map<String, dynamic>> protectedSos;
  final bool protectionActive;

  String get firstName => fullName.split(' ').first;

  String get initials => fullName
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  /// Numéro lisible : +221 77 123 45 67.
  String get phoneDisplay {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length != 12 || !d.startsWith('221')) return phone;
    final l = d.substring(3);
    return '+221 ${l.substring(0, 2)} ${l.substring(2, 5)} ${l.substring(5, 7)} ${l.substring(7)}';
  }
}
