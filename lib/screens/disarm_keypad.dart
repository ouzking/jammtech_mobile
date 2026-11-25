import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/widgets.dart';

/// Clavier numérique de désarmement. Renvoie le code saisi (4 à 8 chiffres),
/// ou `null` si l'utilisateur annule. Le code n'est jamais conservé.
Future<String?> showDisarmKeypad(BuildContext context) => showCodeKeypad(
  context,
  title: 'Désarmer la maison',
  subtitle: 'Saisissez votre code de désarmement',
);

/// Clavier de saisie de code générique (désarmement, PIN de l'app).
Future<String?> showCodeKeypad(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CodeKeypad(
      title: title,
      subtitle: subtitle,
      onSubmit: (c) => Navigator.pop(context, c),
    ),
  );
}

class CodeKeypad extends StatefulWidget {
  const CodeKeypad({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final ValueChanged<String> onSubmit;

  @override
  State<CodeKeypad> createState() => _CodeKeypadState();
}

class _CodeKeypadState extends State<CodeKeypad> {
  static const _min = 4;
  static const _max = 8;
  String _code = '';

  void _tap(String d) {
    if (_code.length >= _max) return;
    HapticFeedback.selectionClick();
    setState(() => _code += d);
  }

  void _back() {
    if (_code.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  void _submit() {
    if (_code.length < _min) return;
    final c = _code;
    setState(() => _code = '');
    widget.onSubmit(c);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: t.headlineSmall),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Gap.xl),
            SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (
                    var i = 0;
                    i < (_code.length < _min ? _min : _code.length);
                    i++
                  )
                    AnimatedContainer(
                      duration: Motion.fast,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _code.length
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        border: Border.all(
                          color: AppColors.textTertiary,
                          width: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xl),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final d in row) _Key(label: d, onTap: () => _tap(d)),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Key(
                  icon: Icons.backspace_outlined,
                  semantic: 'Effacer',
                  onTap: _back,
                ),
                _Key(label: '0', onTap: () => _tap('0')),
                _Key(
                  icon: Icons.check_rounded,
                  semantic: 'Valider',
                  accent: true,
                  onTap: _code.length >= _min ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semantic,
    this.accent = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semantic;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Pressable(
        onTap: onTap,
        haptic: false,
        semanticLabel: semantic ?? label,
        child: Container(
          width: 76,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: accent && onTap != null ? AppColors.brandGradient : null,
            color: accent ? null : AppColors.surfaceHigh,
            borderRadius: Radii.lgAll,
            border: Border.all(color: AppColors.border),
          ),
          child: label != null
              ? Text(label!, style: Theme.of(context).textTheme.headlineSmall)
              : Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
