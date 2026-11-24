import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:jammtech/core/utils/validators.dart';
import 'package:jammtech/main.dart';
import 'package:jammtech/routes.dart';

void main() {
  // Pas de téléchargement de polices pendant les tests.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Validators', () {
    test('phone accepte les numéros sénégalais valides', () {
      expect(Validators.phone('77 123 45 67'), isNull);
      expect(Validators.phone('338234567'), isNull);
      expect(Validators.phone('12345'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });

    test('password exige 8 caractères', () {
      expect(Validators.password('court'), isNotNull);
      expect(Validators.password('suffisant'), isNull);
    });

    test('passwordStrength progresse avec la complexité', () {
      expect(Validators.passwordStrength(''), 0);
      expect(
        Validators.passwordStrength('Abcdef12!xyz'),
        greaterThan(Validators.passwordStrength('abcdefgh')),
      );
    });
  });

  testWidgets('la connexion refuse un formulaire vide', (tester) async {
    await tester.pumpWidget(const JammTechApp(initialRoute: AppRoutes.login));
    await tester.pumpAndSettle();

    expect(find.text('Bon retour'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Le numéro est obligatoire'), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire'), findsOneWidget);
  });

  testWidgets('l’onboarding avance page par page', (tester) async {
    await tester.pumpWidget(
      const JammTechApp(initialRoute: AppRoutes.onboarding),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('les écrans de profil sont routés', (tester) async {
    for (final route in [
      AppRoutes.settings,
      AppRoutes.security,
      AppRoutes.notifications,
      AppRoutes.help,
    ]) {
      await tester.pumpWidget(
        JammTechApp(key: UniqueKey(), initialRoute: route),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
      expect(find.byType(Scaffold), findsWidgets, reason: route);
    }
  });

  testWidgets('l’accueil affiche le SOS et les actions rapides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const JammTechApp(initialRoute: AppRoutes.home));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Besoin d’aide ?'), findsOneWidget);
    expect(find.text('Actions rapides'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
