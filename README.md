# JammTech — Mobile

**La paix dans votre poche.** Application Flutter de sécurité personnelle et de maison connectée : alerte SOS, localisation en direct, alertes, caméras et appareils domestiques.

## Démarrage

```bash
flutter pub get
flutter run
flutter test
```

Configuration requise avant de lancer la carte :

- **Android** : remplacer `TA_API_KEY_ICI` dans `android/app/src/main/AndroidManifest.xml` par une clé Google Maps.
- **iOS** : appeler `GMSServices.provideAPIKey("…")` dans `ios/Runner/AppDelegate.swift`.

## Architecture

```
lib/
├── core/
│   ├── theme/       Charte graphique : couleurs, typographie, espacements, animations
│   ├── widgets/     Composants réutilisables (cartes, boutons, champs, réglages…)
│   └── utils/       Validateurs, formatage, appels téléphoniques
├── data/
│   ├── models.dart      Modèles typés
│   └── demo_data.dart   Données de démonstration (à remplacer par Supabase)
├── screens/         Écrans (coquille à onglets, SOS, carte, alertes, maison, profil…)
├── routes.dart      Routes nommées
└── main.dart
```

## Backend

Le backend (Supabase) est développé dans [ouzking/jammtech_backend](https://github.com/ouzking/jammtech_backend).
Le cahier des charges est dans [docs/BACKEND_PROMPT.md](docs/BACKEND_PROMPT.md).
Les points à brancher côté mobile sont marqués `// TODO` dans le code.
