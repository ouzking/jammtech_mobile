import 'package:flutter/foundation.dart';

import '../backend.dart';
import '../demo_data.dart';
import '../models.dart';

/// Résultat d'un changement de mode d'armement.
class ArmResult {
  const ArmResult(this.mode, this.warnings);

  final ArmMode mode;
  final List<ArmWarning> warnings;
}

/// Maison : mode d'armement, désarmement par code, appareils, codes de sécurité.
class HomeRepository {
  HomeRepository._();
  static final instance = HomeRepository._();

  final devices = ValueNotifier<List<SmartDevice>>(
    Backend.enabled ? const [] : DemoData.devices(),
  );

  Future<List<SmartDevice>> refreshDevices(String? homeId) async {
    if (!Backend.enabled) return devices.value;
    if (homeId == null) return devices.value = const [];
    try {
      final rows = await Backend.client
          .from('devices')
          .select()
          .eq('home_id', homeId)
          .order('type');
      return devices.value = [for (final r in rows) SmartDevice.fromJson(r)];
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> setDeviceOn(SmartDevice d, bool on) async {
    final previous = d.on;
    d.on = on;
    devices.value = [...devices.value];
    if (!Backend.enabled) return;
    try {
      await Backend.client.from('devices').update({'is_on': on}).eq('id', d.id);
    } catch (e) {
      d.on = previous;
      devices.value = [...devices.value];
      throw toAppException(e);
    }
  }

  /// Présence / Absence. Le désarmement passe **toujours** par [disarm].
  Future<ArmResult> setArmMode(
    String? homeId,
    ArmMode mode, {
    required String clientDevice,
  }) async {
    assert(mode != ArmMode.disarmed);
    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return ArmResult(mode, const []);
    }
    try {
      final r = await Backend.rpc<Map<String, dynamic>>('set_arm_mode', {
        'p_home_id': homeId,
        'p_mode': mode.name,
        'p_client_device': clientDevice,
      });
      return ArmResult(ArmMode.parse(r['arm_mode']), _warnings(r));
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Désarmement par code.
  ///
  /// ⚠️ Code de contrainte : le serveur répond exactement comme pour un
  /// désarmement réussi. Cette méthode ne distingue rien et l'appelant ne doit
  /// rien faire de différent. La position est envoyée **à chaque** appel
  /// lorsqu'elle est connue.
  Future<ArmResult> disarm({
    required String? homeId,
    required String code,
    required String clientDevice,
    double? lat,
    double? lng,
    double? accuracy,
  }) async {
    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (code != '1234' && code != '9999') {
        throw const AppException(
          'Code incorrect',
          code: 'invalid_code',
          status: 401,
        );
      }
      return const ArmResult(ArmMode.disarmed, []);
    }
    try {
      final r = await Backend.invoke(
        'disarm',
        body: {
          'home_id': homeId,
          'code': code,
          'client_device': clientDevice,
          'lat': ?lat,
          'lng': ?lng,
          'accuracy_m': ?accuracy,
        },
      );
      return ArmResult(ArmMode.parse(r['arm_mode']), _warnings(r));
    } catch (e) {
      throw toAppException(e);
    }
  }

  List<ArmWarning> _warnings(Map<String, dynamic> r) => [
    for (final w in (r['warnings'] as List? ?? const []))
      ArmWarning.fromJson((w as Map).cast<String, dynamic>()),
  ];

  // --- Codes de sécurité ---------------------------------------------------

  Future<({bool hasDisarm, bool hasDuress})> securityCodesStatus() async {
    if (!Backend.enabled) return (hasDisarm: true, hasDuress: false);
    try {
      final r = await Backend.rpc<Map<String, dynamic>>(
        'get_security_codes_status',
      );
      return (
        hasDisarm: r['has_disarm_code'] == true,
        hasDuress: r['has_duress_code'] == true,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// `null` = inchangé, `''` = supprimer.
  Future<void> setSecurityCodes({
    String? currentDisarmCode,
    String? newDisarmCode,
    String? newDuressCode,
  }) async {
    if (!Backend.enabled) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return;
    }
    try {
      await Backend.rpc<dynamic>('set_security_codes', {
        'p_current_disarm_code': currentDisarmCode,
        'p_new_disarm_code': newDisarmCode,
        'p_new_duress_code': newDuressCode,
      });
    } catch (e) {
      throw toAppException(e);
    }
  }

  void clear() => devices.value = const [];
}
