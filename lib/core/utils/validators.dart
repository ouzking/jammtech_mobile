/// Validateurs de formulaires (messages en français).
abstract final class Validators {
  static String? required(String? v, [String field = 'Ce champ']) =>
      (v == null || v.trim().isEmpty) ? '$field est obligatoire' : null;

  /// Numéro sénégalais : 9 chiffres commençant par 7 (mobile) ou 3 (fixe).
  static String? phone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Le numéro est obligatoire';
    if (!RegExp(r'^[37]\d{8}$').hasMatch(digits)) {
      return 'Numéro invalide (ex. 77 123 45 67)';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Le mot de passe est obligatoire';
    if (v.length < 8) return 'Au moins 8 caractères';
    return null;
  }

  /// Nouveau mot de passe : règle du serveur (8 caractères, lettres + chiffres).
  static String? newPassword(String? v) {
    final base = password(v);
    if (base != null) return base;
    if (!RegExp(r'[A-Za-z]').hasMatch(v!) || !RegExp(r'\d').hasMatch(v)) {
      return 'Utilisez des lettres et des chiffres';
    }
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Le nom est obligatoire';
    if (v.trim().length < 3) return 'Nom trop court';
    return null;
  }

  /// Score de robustesse de 0 (vide) à 4 (excellent).
  static int passwordStrength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 8) score++;
    if (v.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'\d').hasMatch(v)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) score++;
    return score.clamp(1, 4);
  }
}
