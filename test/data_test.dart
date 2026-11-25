import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jammtech/data/backend.dart';
import 'package:jammtech/data/models.dart';

void main() {
  group('toE164', () {
    test('normalise les formats saisis', () {
      expect(toE164('77 123 45 67'), '+221771234567');
      expect(toE164('771234567'), '+221771234567');
      expect(toE164('+221 77 123 45 67'), '+221771234567');
      expect(toE164('221771234567'), '+221771234567');
    });
  });

  group('Dashboard.fromJson', () {
    // Extrait réel renvoyé par get_dashboard() sur le backend local (seed).
    final json = {
      'profile': {
        'id': '11111111-1111-4111-8111-111111111111',
        'plan': 'free',
        'phone': '+221771234567',
        'language': 'fr',
        'full_name': 'Moussa Ndiaye',
        'avatar_url': null,
      },
      'home': {
        'id': 'b94d7205-24fc-459f-9131-5ba9bc137002',
        'name': 'Résidence principale',
        'role': 'owner',
        'arm_mode': 'home',
        'arm_mode_changed_at': '2026-11-25T12:39:41.890945+00:00',
      },
      'cameras': {'total': 5, 'online': 4},
      'devices_count': 9,
      'contacts_count': 3,
      'protected_people_count': 0,
      'alerts': {'total': 5, 'unresolved': 3, 'critical_unresolved': 1},
      'recent_alerts': [
        {
          'id': 'a1',
          'title': 'Intrusion détectée',
          'description': '…',
          'severity': 'critical',
          'category': 'intrusion',
          'location_label': 'Entrée principale',
          'created_at': '2026-11-25T12:00:00Z',
          'resolved': false,
        },
      ],
      'active_sos': null,
      'location_sharing': null,
      'protected_sos': [
        {'user_id': 'u2', 'silent': true, 'full_name': 'Awa Ndiaye'},
      ],
      'protection_active': true,
    };

    test('lit le profil, la maison et les compteurs', () {
      final d = Dashboard.fromJson(json);
      expect(d.firstName, 'Moussa');
      expect(d.initials, 'MN');
      expect(d.phoneDisplay, '+221 77 123 45 67');
      expect(d.armMode, ArmMode.home);
      expect(d.camerasOnline, 4);
      expect(d.camerasTotal, 5);
      expect(d.alertsUnresolved, 3);
      expect(d.recentAlerts.single.severity, AlertSeverity.critical);
      expect(d.recentAlerts.single.resolved, isFalse);
      expect(d.protectedSos.single['silent'], isTrue);
      expect(d.locationSharing, isFalse);
      expect(d.protectionActive, isTrue);
    });
  });

  group('SecurityAlert.fromJson', () {
    test('resolved_at de la table vaut « traitée »', () {
      final a = SecurityAlert.fromJson({
        'id': 'x',
        'severity': 'warning',
        'created_at': '2026-11-25T12:00:00Z',
        'resolved_at': '2026-11-25T13:00:00Z',
      });
      expect(a.resolved, isTrue);
      expect(a.severity, AlertSeverity.warning);
    });
  });

  group('toAppException', () {
    test('reprend le message français des Edge Functions', () {
      final e = toAppException(
        const FunctionException(
          status: 401,
          details: {
            'error': {'code': 'invalid_code', 'message': 'Code incorrect'},
          },
        ),
      );
      expect(e.message, 'Code incorrect');
      expect(e.code, 'invalid_code');
      expect(e.status, 401);
      expect(e.network, isFalse);
    });

    test('traduit les erreurs d’authentification', () {
      final e = toAppException(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );
      expect(e.message, 'Numéro ou mot de passe incorrect.');
    });

    test('garde les erreurs métier PostgREST', () {
      final e = toAppException(
        const PostgrestException(
          message: 'Vous ne pouvez pas avoir plus de 5 contacts de confiance',
          code: 'P0001',
        ),
      );
      expect(e.message, contains('5 contacts'));
    });
  });
}
