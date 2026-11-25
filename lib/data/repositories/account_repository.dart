import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import '../demo_data.dart';
import '../models.dart';

/// Accueil, profil, réglages, préférences de notification et conformité.
class AccountRepository {
  AccountRepository._();
  static final instance = AccountRepository._();

  /// Dernier résumé connu de l'accueil ; `null` avant le premier chargement.
  final dashboard = ValueNotifier<Dashboard?>(null);

  /// URL signée de l'avatar (valide 1 h).
  final avatarUrl = ValueNotifier<String?>(null);

  String? get _uid => Backend.uid;

  Future<Dashboard> refreshDashboard() async {
    if (!Backend.enabled) {
      final d = DemoData.dashboard();
      dashboard.value = d;
      return d;
    }
    try {
      final raw = await Backend.rpc<Map<String, dynamic>>('get_dashboard');
      final d = Dashboard.fromJson(raw);
      dashboard.value = d;
      if (d.avatarPath != null && avatarUrl.value == null) {
        _refreshAvatarUrl(d.avatarPath!);
      }
      return d;
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> _refreshAvatarUrl(String path) async {
    try {
      avatarUrl.value = await Backend.client.storage
          .from('avatars')
          .createSignedUrl(path, 3600);
    } catch (_) {
      // Avatar non bloquant.
    }
  }

  /// Envoie l'avatar (déjà redimensionné à 600 px par le sélecteur).
  Future<void> uploadAvatar(Uint8List bytes) async {
    if (!Backend.enabled) return;
    final path = '$_uid/avatar.jpg';
    try {
      await Backend.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      await Backend.client
          .from('profiles')
          .update({'avatar_url': path})
          .eq('id', _uid!);
      avatarUrl.value = null;
      await _refreshAvatarUrl(path);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> setLanguage(String code) async {
    if (!Backend.enabled) return;
    try {
      await Backend.client
          .from('profiles')
          .update({'language': code})
          .eq('id', _uid!);
    } catch (e) {
      throw toAppException(e);
    }
  }

  // --- Réglages ------------------------------------------------------------

  Future<Map<String, dynamic>> settings() =>
      _single('user_settings', DemoData.settings);

  Future<void> updateSettings(Map<String, dynamic> values) =>
      _update('user_settings', values);

  Future<Map<String, dynamic>> notificationPreferences() =>
      _single('notification_preferences', DemoData.notificationPreferences);

  Future<void> updateNotificationPreferences(Map<String, dynamic> values) =>
      _update('notification_preferences', values);

  Future<Map<String, dynamic>> _single(
    String table,
    Map<String, dynamic> demo,
  ) async {
    if (!Backend.enabled) return Map.of(demo);
    try {
      return await Backend.client.from(table).select().single();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> _update(String table, Map<String, dynamic> values) async {
    if (!Backend.enabled) return;
    try {
      await Backend.client.from(table).update(values).eq('user_id', _uid!);
    } catch (e) {
      throw toAppException(e);
    }
  }

  // --- Push ----------------------------------------------------------------

  Future<void> registerPushToken(
    String token, {
    required String platform,
    required String deviceLabel,
  }) async {
    if (!Backend.enabled || _uid == null) return;
    try {
      await Backend.rpc<dynamic>('register_push_token', {
        'p_token': token,
        'p_platform': platform,
        'p_device_label': deviceLabel,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('register_push_token : $e');
    }
  }

  // --- Conformité ----------------------------------------------------------

  /// Export complet des données personnelles, en JSON indenté.
  Future<String> exportMyData() async {
    if (!Backend.enabled) {
      return const JsonEncoder.withIndent('  ').convert({
        'profile': {
          'full_name': DemoData.userName,
          'phone': DemoData.userPhone,
        },
        'note': 'Mode démo : aucune donnée serveur.',
      });
    }
    try {
      final data = await Backend.rpc<dynamic>('export_my_data');
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> deleteAccount() async {
    if (!Backend.enabled) return;
    try {
      await Backend.invoke('delete-account', body: {'confirm': 'SUPPRIMER'});
      await Backend.client.auth.signOut();
    } catch (e) {
      throw toAppException(e);
    }
  }

  void clear() {
    dashboard.value = null;
    avatarUrl.value = null;
  }
}
