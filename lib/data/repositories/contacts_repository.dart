import 'package:flutter/foundation.dart';

import '../backend.dart';
import '../demo_data.dart';
import '../models.dart';

/// Contacts de confiance (max 5) et, côté proche, personnes que je protège.
class ContactsRepository {
  ContactsRepository._();
  static final instance = ContactsRepository._();

  final contacts = ValueNotifier<List<TrustedContact>>(
    Backend.enabled ? const [] : DemoData.contacts,
  );

  final protectedPeople = ValueNotifier<List<ProtectedPerson>>(const []);

  Future<List<TrustedContact>> refresh() async {
    if (!Backend.enabled) return contacts.value = DemoData.contacts;
    try {
      final rows = await Backend.client
          .from('trusted_contacts')
          .select()
          .order('priority');
      return contacts.value = [
        for (final r in rows) TrustedContact.fromJson(r),
      ];
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> add({
    required String name,
    required String relation,
    required String phone,
  }) async {
    if (!Backend.enabled) {
      contacts.value = [
        ...contacts.value,
        TrustedContact(name: name, relation: relation, phone: toE164(phone)),
      ];
      return;
    }
    try {
      await Backend.client.from('trusted_contacts').insert({
        'owner_id': Backend.uid,
        'name': name.trim(),
        'relation': relation.trim(),
        'phone': toE164(phone),
        'priority': contacts.value.length + 1,
      });
      await refresh();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> remove(TrustedContact c) async {
    if (!Backend.enabled) {
      contacts.value = [...contacts.value]..remove(c);
      return;
    }
    try {
      await Backend.client.from('trusted_contacts').delete().eq('id', c.id);
      await refresh();
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<List<ProtectedPerson>> refreshProtected({
    List<Map<String, dynamic>> activeSos = const [],
  }) async {
    if (!Backend.enabled) return protectedPeople.value = const [];
    try {
      final rows = await Backend.rpc<List<dynamic>>('get_people_i_protect');
      final sosByUser = {for (final s in activeSos) s['user_id'] as String?: s};
      return protectedPeople.value = [
        for (final r in rows)
          () {
            final p = ProtectedPerson.fromJson(r as Map<String, dynamic>);
            final s = sosByUser[p.userId];
            return s == null
                ? p
                : p.copyWith(inSos: true, silentSos: s['silent'] == true);
          }(),
      ];
    } catch (e) {
      throw toAppException(e);
    }
  }

  void clear() {
    contacts.value = const [];
    protectedPeople.value = const [];
  }
}
