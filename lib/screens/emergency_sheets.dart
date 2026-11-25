import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import '../data/repositories/contacts_repository.dart';
import '../data/models.dart';

/// Feuille « Numéros d'urgence » : un appui lance l'appel.
Future<void> showEmergencyNumbersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetBody(
      title: 'Numéros d’urgence',
      subtitle: 'Un appui pour appeler directement.',
      children: [
        for (final n in DemoData.emergencyNumbers)
          _CallRow(
            leading: IconBadge(icon: n.icon, color: n.color),
            title: n.label,
            subtitle: n.number,
            onCall: () => callNumber(context, n.number),
          ),
      ],
    ),
  );
}

/// Feuille « Contacts de confiance ».
Future<void> showTrustedContactsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SheetBody(
      title: 'Contacts de confiance',
      subtitle: 'Prévenus automatiquement lors d’une alerte SOS.',
      children: [
        for (final c in ContactsRepository.instance.contacts.value)
          _CallRow(
            leading: ContactAvatar(contact: c),
            title: c.name,
            subtitle: '${c.relation} · ${c.phone}',
            onCall: () => callNumber(context, c.phone),
          ),
      ],
    ),
  );
}

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.size = 44});

  final TrustedContact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.violet.withValues(alpha: 0.9),
            AppColors.brand.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Text(
        contact.initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.headlineSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: Gap.lg),
            for (final c in children) ...[c, const SizedBox(height: Gap.xs)],
          ],
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onCall,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
      onTap: onCall,
      child: Row(
        children: [
          leading,
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.successGradient,
            ),
            child: const Icon(
              Icons.call_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
