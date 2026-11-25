import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/contacts_repository.dart';
import '../services/session.dart';
import 'app_page.dart';
import 'emergency_sheets.dart' show ContactAvatar;

/// Contacts de confiance : prévenus automatiquement lors d'un SOS (max 5).
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  static const _max = 5;
  final _repo = ContactsRepository.instance;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await _repo.refresh();
    } on AppException catch (e) {
      if (mounted) _error(e);
    }
  }

  void _error(AppException e) => showAppSnack(
    context,
    e.message,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddContactSheet(),
    );
    if (added == true && mounted) {
      Session.refreshAll().ignore();
      showAppSnack(context, 'Contact ajouté');
    }
  }

  Future<void> _remove(TrustedContact c) async {
    final ok = await confirmAction(
      context,
      title: 'Retirer ${c.name} ?',
      message: 'Cette personne ne sera plus prévenue en cas de SOS.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _repo.remove(c);
      Session.refreshAll().ignore();
    } on AppException catch (e) {
      if (mounted) _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder(
      valueListenable: _repo.contacts,
      builder: (context, contacts, _) => AppPage(
        title: 'Contacts de confiance',
        subtitle: '${contacts.length} / $_max · prévenus en cas de SOS',
        onRefresh: _refresh,
        actions: [
          GlassIconButton(
            icon: Icons.person_add_alt_1_rounded,
            tooltip: 'Ajouter',
            onPressed: contacts.length >= _max ? null : _add,
          ),
        ],
        slivers: [
          if (contacts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.groups_rounded,
                title: 'Aucun contact',
                message:
                    'Ajoutez jusqu’à 5 proches : ils recevront votre position '
                    'et une alerte immédiate si vous déclenchez un SOS.',
                action: AppButton(
                  label: 'Ajouter un proche',
                  icon: Icons.person_add_alt_1_rounded,
                  expand: false,
                  onPressed: _add,
                ),
              ),
            )
          else
            PageSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsGroup(
                    children: [
                      for (final c in contacts)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Gap.md,
                            12,
                            Gap.xs,
                            12,
                          ),
                          child: Row(
                            children: [
                              ContactAvatar(contact: c, size: 44),
                              const SizedBox(width: Gap.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name, style: t.titleSmall),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.relation} · ${c.phone}',
                                      style: t.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    StatusPill(
                                      label: c.hasApp
                                          ? 'Push + SMS'
                                          : 'SMS uniquement',
                                      color: c.hasApp
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                      dot: c.hasApp,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Appeler',
                                onPressed: () => callNumber(context, c.phone),
                                icon: const Icon(
                                  Icons.call_outlined,
                                  color: AppColors.success,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Retirer',
                                onPressed: () => _remove(c),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    'Les proches qui ont l’application reçoivent une notification '
                    'et peuvent suivre votre position en direct. Les autres '
                    'reçoivent un SMS avec un lien de suivi.',
                    style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _relation, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ContactsRepository.instance.add(
        name: _name.text,
        relation: _relation.text,
        phone: _phone.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      HapticFeedback.heavyImpact();
      showAppSnack(
        context,
        e.message,
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.page,
        0,
        Gap.page,
        Gap.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ajouter un proche',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: Gap.lg),
              AppTextField(
                controller: _name,
                label: 'Nom complet',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: Validators.name,
              ),
              const SizedBox(height: Gap.md),
              AppTextField(
                controller: _relation,
                label: 'Lien (épouse, frère, voisin…)',
                icon: Icons.favorite_outline_rounded,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => Validators.required(v, 'Le lien'),
              ),
              const SizedBox(height: Gap.md),
              AppTextField(
                controller: _phone,
                label: 'Numéro de téléphone',
                icon: Icons.phone_iphone_rounded,
                prefixText: '+221 ',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: Validators.phone,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Gap.xl),
              AppButton(
                label: 'Ajouter',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
