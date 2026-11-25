import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

/// Point d'accès unique au backend Supabase.
abstract final class Backend {
  static bool _ready = false;

  /// `false` en mode démo : les dépôts renvoient alors les données locales.
  static bool get enabled => _ready;

  static SupabaseClient get client => Supabase.instance.client;

  static String? get uid => _ready ? client.auth.currentUser?.id : null;

  static Future<void> init() async {
    if (!Env.hasBackend) return;
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      debug: false,
    );
    _ready = true;
  }

  static bool get isSignedIn => !_ready || client.auth.currentSession != null;

  /// Appelle une Edge Function et renvoie son corps JSON.
  static Future<Map<String, dynamic>> invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) async {
    final res = await client.functions.invoke(fn, body: body);
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  static Future<T> rpc<T>(String fn, [Map<String, dynamic>? params]) async {
    final res = await client.rpc(fn, params: params);
    return res as T;
  }
}

/// Erreur affichable telle quelle à l'utilisateur.
class AppException implements Exception {
  const AppException(
    this.message, {
    this.code,
    this.status,
    this.network = false,
  });

  final String message;
  final String? code;
  final int? status;

  /// Vrai si l'échec vient du réseau (on peut réessayer).
  final bool network;

  @override
  String toString() => message;
}

/// Convertit n'importe quelle erreur backend en message français.
AppException toAppException(Object e) {
  if (e is AppException) return e;

  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] is Map) {
      final err = d['error'] as Map;
      return AppException(
        (err['message'] as String?) ?? _generic,
        code: err['code'] as String?,
        status: e.status,
      );
    }
    return AppException(_generic, status: e.status);
  }

  if (e is PostgrestException) {
    // Les erreurs métier du backend sont déjà en français.
    final businessCodes = {'P0001', '23505', '23514', '42501', '22023'};
    final msg = businessCodes.contains(e.code) || _looksFrench(e.message)
        ? e.message
        : _generic;
    return AppException(msg, code: e.code);
  }

  if (e is AuthException) {
    return AppException(
      _authMessage(e),
      code: e.code,
      status: int.tryParse(e.statusCode ?? ''),
    );
  }

  if (e is StorageException) {
    return AppException(_generic, code: e.statusCode);
  }

  if (e is SocketException || e is TimeoutException || e is ClientException) {
    return const AppException(
      'Connexion impossible. Vérifiez votre accès Internet.',
      network: true,
    );
  }

  if (kDebugMode) debugPrint('Erreur non gérée : $e');
  return const AppException(_generic);
}

const _generic = 'Une erreur est survenue. Réessayez dans un instant.';

bool _looksFrench(String m) => RegExp(
  r'[éèêàçù]|\b(le|la|les|vous|votre|pas|est)\b',
  caseSensitive: false,
).hasMatch(m);

String _authMessage(AuthException e) {
  final code = e.code ?? '';
  final m = e.message.toLowerCase();
  if (code == 'invalid_credentials' || m.contains('invalid login')) {
    return 'Numéro ou mot de passe incorrect.';
  }
  if (code == 'phone_not_confirmed' || m.contains('not confirmed')) {
    return 'Votre numéro n’est pas encore vérifié. Saisissez le code reçu par SMS.';
  }
  if (code == 'user_already_exists' || m.contains('already registered')) {
    return 'Un compte existe déjà avec ce numéro.';
  }
  if (code == 'otp_expired' ||
      m.contains('expired') ||
      m.contains('invalid otp') ||
      m.contains('token has expired')) {
    return 'Code incorrect ou expiré.';
  }
  if (code == 'weak_password' || m.contains('password should')) {
    return 'Mot de passe trop faible : 8 caractères minimum, lettres et chiffres.';
  }
  if (code == 'over_sms_send_rate_limit' || e.statusCode == '429') {
    return _looksFrench(e.message)
        ? e.message
        : 'Trop de demandes. Patientez avant de demander un nouveau code.';
  }
  if (code == 'same_password') {
    return 'Le nouveau mot de passe doit être différent de l’ancien.';
  }
  if (code == 'user_not_found' || code == 'otp_disabled') {
    return 'Aucun compte n’est associé à ce numéro.';
  }
  return _looksFrench(e.message) ? e.message : _generic;
}

/// Contenu utile d'un message Realtime « broadcast » (enveloppé ou non).
Map<String, dynamic> broadcastBody(Map<String, dynamic> message) {
  final inner = message['payload'];
  return inner is Map ? inner.cast<String, dynamic>() : message;
}

/// Convertit un numéro saisi (« 77 123 45 67 ») en E.164 (+221771234567).
String toE164(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('221') && digits.length == 12) return '+$digits';
  return '+221$digits';
}
