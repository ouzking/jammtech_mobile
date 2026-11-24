import 'package:flutter/material.dart';

/// Palette JammTech — une seule source de vérité pour toutes les couleurs.
abstract final class AppColors {
  // Fonds
  static const background = Color(0xFF060A14);
  static const backgroundElevated = Color(0xFF0A1122);
  static const surface = Color(0xFF0F1729);
  static const surfaceHigh = Color(0xFF162036);
  static const surfaceHighest = Color(0xFF1E2A44);

  // Marque
  static const brand = Color(0xFF4F7DFF);
  static const brandBright = Color(0xFF7CA0FF);
  static const brandDeep = Color(0xFF2A4BD7);
  static const navy = Color(0xFF0A1F44);

  // Sémantique
  static const danger = Color(0xFFFF3B5C);
  static const dangerDeep = Color(0xFFB3123A);
  static const warning = Color(0xFFFFB547);
  static const success = Color(0xFF2EE6A6);
  static const info = Color(0xFF5CC8FF);
  static const violet = Color(0xFFA78BFA);

  // Texte
  static const textPrimary = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFFA3ADC2);
  static const textTertiary = Color(0xFF66718A);

  // Lignes
  static const border = Color(0x14FFFFFF); // 8 %
  static const borderStrong = Color(0x24FFFFFF); // 14 %

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandBright, brand, brandDeep],
  );

  static const dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5A76), danger, dangerDeep],
  );

  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34F5B4), Color(0xFF14B88A)],
  );
}
