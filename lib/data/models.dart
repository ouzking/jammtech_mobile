import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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
  });

  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final String location;
  final DateTime time;
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
  });

  final String id;
  final String title;
  final String camera;
  final DateTime time;
  final Duration duration;
  final bool motion;
}

class TrustedContact {
  const TrustedContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  final String name;
  final String relation;
  final String phone;

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
}

class SmartDevice {
  SmartDevice({
    required this.name,
    required this.room,
    required this.icon,
    required this.color,
    this.on = false,
  });

  final String name;
  final String room;
  final IconData icon;
  final Color color;
  bool on;
}
