import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Verrouillage local de l'application : PIN et biométrie.
///
/// Rien de tout cela n'est envoyé au serveur (exigence du backend). Le PIN
/// est conservé dans le stockage chiffré du système (Keystore / Keychain).
class LocalSecurity with WidgetsBindingObserver {
  LocalSecurity._();
  static final instance = LocalSecurity._();

  static const _kPin = 'app_pin';
  static const _kBio = 'biometrics_enabled';
  static const _kAutoLock = 'auto_lock_enabled';
  static const autoLockAfter = Duration(minutes: 1);

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  bool pinEnabled = false;
  bool biometricsEnabled = false;
  bool autoLock = true;
  DateTime? _pausedAt;

  /// Appelé quand l'app doit être verrouillée (retour après 1 min).
  VoidCallback? onLockRequired;

  Future<void> load() async {
    try {
      pinEnabled = await _storage.containsKey(key: _kPin);
      biometricsEnabled = await _storage.read(key: _kBio) == 'true';
      autoLock = await _storage.read(key: _kAutoLock) != 'false';
    } catch (e) {
      if (kDebugMode) debugPrint('LocalSecurity.load : $e');
    }
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _kPin, value: pin);
    pinEnabled = true;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _kPin);
    await _storage.delete(key: _kBio);
    pinEnabled = false;
    biometricsEnabled = false;
  }

  Future<bool> checkPin(String pin) async =>
      await _storage.read(key: _kPin) == pin;

  Future<bool> biometricsAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometrics(bool v) async {
    await _storage.write(key: _kBio, value: '$v');
    biometricsEnabled = v;
  }

  Future<void> setAutoLock(bool v) async {
    await _storage.write(key: _kAutoLock, value: '$v');
    autoLock = v;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (pinEnabled && autoLock && away >= autoLockAfter) {
        onLockRequired?.call();
      }
    }
  }
}
