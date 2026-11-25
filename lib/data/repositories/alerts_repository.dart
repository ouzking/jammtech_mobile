import 'package:flutter/foundation.dart';

import '../backend.dart';
import '../demo_data.dart';
import '../models.dart';

/// Alertes de sécurité : liste, traitement, réouverture.
class AlertsRepository {
  AlertsRepository._();
  static final instance = AlertsRepository._();

  final alerts = ValueNotifier<List<SecurityAlert>>(
    Backend.enabled ? const [] : DemoData.alerts,
  );

  int get unresolvedCount => alerts.value.where((a) => !a.resolved).length;

  Future<List<SecurityAlert>> refresh() async {
    if (!Backend.enabled) return alerts.value = [...DemoData.alerts];
    try {
      final rows = await Backend.client
          .from('security_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return alerts.value = [for (final r in rows) SecurityAlert.fromJson(r)];
    } catch (e) {
      throw toAppException(e);
    }
  }

  void _notify() => alerts.value = [...alerts.value];

  /// Marque une alerte comme traitée (ou la rouvre). Mise à jour optimiste.
  Future<void> setResolved(SecurityAlert a, bool resolved) async {
    final previous = a.resolved;
    a.resolved = resolved;
    _notify();
    if (!Backend.enabled) return;
    try {
      await Backend.rpc<dynamic>('resolve_alert', {
        'p_alert_id': a.id,
        'p_resolved': resolved,
      });
    } catch (e) {
      a.resolved = previous;
      _notify();
      throw toAppException(e);
    }
  }

  /// Traite toutes les alertes ouvertes ; renvoie celles qui l'ont été.
  Future<List<SecurityAlert>> resolveAll() async {
    final open = alerts.value.where((a) => !a.resolved).toList();
    for (final a in open) {
      a.resolved = true;
    }
    _notify();
    if (!Backend.enabled) return open;
    try {
      await Backend.rpc<dynamic>('resolve_all_alerts');
      return open;
    } catch (e) {
      for (final a in open) {
        a.resolved = false;
      }
      _notify();
      throw toAppException(e);
    }
  }

  /// Annule un « tout traiter » : rouvre chaque alerte.
  Future<void> reopen(List<SecurityAlert> list) async {
    for (final a in list) {
      await setResolved(a, false);
    }
  }

  void clear() => alerts.value = const [];
}
