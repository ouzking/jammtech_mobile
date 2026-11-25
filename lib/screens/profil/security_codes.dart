import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/repositories/home_repository.dart';
import '../app_page.dart';

/// Code de désarmement et code de contrainte.
///
/// Les codes ne sont jamais stockés ni journalisés sur l'appareil : ils ne
/// vivent que dans les champs de saisie, effacés à la fermeture.
class SecurityCodesScreen extends StatefulWidget {
  const SecurityCodesScreen({super.key});

  @override
  State<SecurityCodesScreen> createState() => _SecurityCodesScreenState();
}

class _SecurityCodesScreenState extends State<SecurityCodesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _disarm = TextEditingController();
  final _duress = TextEditingController();

  bool _loadingStatus = true;
  bool _saving = false;
  bool _hasDisarm = false;
  bool _hasDuress = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    for (final c in [_current, _disarm, _duress]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await HomeRepository.instance.securityCodesStatus();
      if (!mounted) return;
      setState(() {
        _hasDisarm = s.hasDisarm;
        _hasDuress = s.hasDuress;
        _loadingStatus = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loadingStatus = false);
      _error(e.message);
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  String? _codeRule(String? v, {bool optional = true}) {
    final s = v ?? '';
    if (s.isEmpty) return optional ? null : 'Code obligatoire';
    if (!RegExp(r'^\d{4,8}$').hasMatch(s)) return 'De 4 à 8 chiffres';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_disarm.text.isEmpty && _duress.text.isEmpty) {
      _error('Saisissez au moins un nouveau code.');
      return;
    }
    setState(() => _saving = true);
    try {
      await HomeRepository.instance.setSecurityCodes(
        currentDisarmCode: _hasDisarm ? _current.text : null,
        newDisarmCode: _disarm.text.isEmpty ? null : _disarm.text,
        newDuressCode: _duress.text.isEmpty ? null : _duress.text,
      );
      for (final c in [_current, _disarm, _duress]) {
        c.clear();
      }
      if (!mounted) return;
      showAppSnack(context, 'Codes enregistrés');
      await _loadStatus();
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _codeField(
    TextEditingController c,
    String label,
    IconData icon, {
    FormFieldValidator<String>? validator,
  }) {
    return AppTextField(
      controller: c,
      label: label,
      icon: icon,
      password: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      validator: validator ?? _codeRule,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'Codes de sécurité',
      glow: AppColors.success,
      slivers: [
        PageSection(
          child: Row(
            children: [
              Expanded(
                child: _StatusTile(
                  label: 'Code de désarmement',
                  set: _hasDisarm,
                  loading: _loadingStatus,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _StatusTile(
                  label: 'Code de contrainte',
                  set: _hasDuress,
                  loading: _loadingStatus,
                ),
              ),
            ],
          ),
        ),
        PageSection(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hasDisarm) ...[
                  _codeField(
                    _current,
                    'Code de désarmement actuel',
                    Icons.lock_outline_rounded,
                    validator: (v) => _codeRule(v, optional: false),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                _codeField(
                  _disarm,
                  _hasDisarm
                      ? 'Nouveau code de désarmement'
                      : 'Code de désarmement',
                  Icons.lock_open_rounded,
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'Utilisé pour désarmer la maison.',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: Gap.lg),
                _codeField(
                  _duress,
                  _hasDuress
                      ? 'Nouveau code de contrainte'
                      : 'Code de contrainte',
                  Icons.warning_amber_rounded,
                  validator: (v) {
                    final base = _codeRule(v);
                    if (base != null) return base;
                    if ((v ?? '').isNotEmpty && v == _disarm.text) {
                      return 'Doit être différent du code de désarmement';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Gap.md),
                AppCard(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderColor: AppColors.danger.withValues(alpha: 0.25),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_moon_outlined,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Si quelqu’un vous force à désarmer, saisissez le code '
                          'de contrainte : l’application se comporte exactement '
                          'comme un désarmement normal, mais vos proches '
                          'reçoivent une alerte discrète avec votre position.',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.xl),
                AppButton(
                  label: 'Enregistrer',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.set,
    required this.loading,
  });

  final String label;
  final bool set;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Gap.xs),
          loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : StatusPill(
                  label: set ? 'Défini' : 'Non défini',
                  color: set ? AppColors.success : AppColors.warning,
                ),
        ],
      ),
    );
  }
}
