import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';
import '../theme/app_colors.dart';

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// « À l'instant », « Il y a 5 min », « Il y a 2 h », « Hier », « 12 mars ».
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'À l’instant';
  if (d.inMinutes < 60) return 'Il y a ${d.inMinutes} min';
  if (d.inHours < 24) return 'Il y a ${d.inHours} h';
  if (d.inDays == 1) return 'Hier';
  if (d.inDays < 7) return 'Il y a ${d.inDays} j';
  return '${t.day} ${_months[t.month - 1]}';
}

String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String clockWithSeconds(DateTime t) => '${clock(t)}:${_two(t.second)}';

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Aujourd’hui';
  if (diff == 1) return 'Hier';
  return '${t.day} ${_months[t.month - 1]}';
}

String duration(Duration d) =>
    '${d.inMinutes}:${_two(d.inSeconds.remainder(60))}';

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5 || h >= 18) return 'Bonsoir';
  return 'Bonjour';
}

/// Lance un appel téléphonique ; affiche une erreur si l'appareil ne peut pas.
Future<void> callNumber(BuildContext context, String number) async {
  final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
  final ok = await canLaunchUrl(uri) && await launchUrl(uri);
  if (!ok && context.mounted) {
    showAppSnack(
      context,
      'Impossible de lancer l’appel vers $number sur cet appareil.',
      icon: Icons.error_outline_rounded,
      color: AppColors.danger,
    );
  }
}
