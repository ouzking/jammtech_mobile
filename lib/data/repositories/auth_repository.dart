import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';

/// Authentification téléphone + mot de passe, vérification par OTP SMS.
class AuthRepository {
  AuthRepository._();
  static final instance = AuthRepository._();

  GoTrueClient get _auth => Backend.client.auth;

  Future<void> _demoDelay() =>
      Future<void>.delayed(const Duration(milliseconds: 700));

  Future<void> signIn(String phone, String password) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.signInWithPassword(phone: toE164(phone), password: password);
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Crée le compte ; un OTP est envoyé. Le numéro doit ensuite être vérifié.
  Future<void> signUp({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.signUp(
        phone: toE164(phone),
        password: password,
        data: {'full_name': fullName.trim()},
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Vérifie le code SMS ; ouvre une session en cas de succès.
  Future<void> verifyOtp(String phone, String code) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.verifyOTP(
        type: OtpType.sms,
        phone: toE164(phone),
        token: code,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> resendSignupOtp(String phone) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.resend(type: OtpType.sms, phone: toE164(phone));
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Mot de passe oublié, étape 1 : code envoyé uniquement si le compte existe.
  Future<void> sendResetCode(String phone) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.signInWithOtp(phone: toE164(phone), shouldCreateUser: false);
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Mot de passe oublié, étape 3 (la session vient de [verifyOtp]).
  Future<void> updatePassword(String password) async {
    if (!Backend.enabled) return _demoDelay();
    try {
      await _auth.updateUser(UserAttributes(password: password));
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Supprime le token push puis ferme la session.
  Future<void> signOut({String? pushToken}) async {
    if (!Backend.enabled) return;
    try {
      if (pushToken != null) {
        await Backend.client
            .from('push_tokens')
            .delete()
            .eq('token', pushToken);
      }
    } catch (_) {
      // La déconnexion ne doit jamais être bloquée par le nettoyage.
    }
    await _auth.signOut();
  }

  // --- Appareils connectés -------------------------------------------------

  Future<List<Map<String, dynamic>>> sessions() async {
    if (!Backend.enabled) {
      return [
        {
          'id': 'demo',
          'user_agent': 'Cet appareil',
          'is_current': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];
    }
    try {
      final r = await Backend.rpc<List<dynamic>>('list_my_sessions');
      return r.cast<Map<String, dynamic>>();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> revokeSession(String id) async {
    if (!Backend.enabled) return;
    try {
      await Backend.rpc<dynamic>('revoke_session', {'p_session_id': id});
    } catch (e) {
      throw toAppException(e);
    }
  }

  // --- Double authentification (TOTP) --------------------------------------

  Future<bool> hasTotp() async {
    if (!Backend.enabled) return false;
    final f = await _auth.mfa.listFactors();
    return f.totp.any((x) => x.status == FactorStatus.verified);
  }

  /// Démarre l'inscription TOTP : renvoie l'id du facteur et le secret à saisir.
  Future<({String factorId, String secret, String uri})> enrollTotp() async {
    try {
      final f = await _auth.mfa.enroll(factorType: FactorType.totp);
      return (factorId: f.id, secret: f.totp!.secret, uri: f.totp!.uri);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> verifyTotp(String factorId, String code) async {
    try {
      final c = await _auth.mfa.challenge(factorId: factorId);
      await _auth.mfa.verify(factorId: factorId, challengeId: c.id, code: code);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> disableTotp() async {
    try {
      final f = await _auth.mfa.listFactors();
      for (final x in f.totp) {
        await _auth.mfa.unenroll(x.id);
      }
    } catch (e) {
      throw toAppException(e);
    }
  }
}
