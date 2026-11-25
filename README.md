# JammTech — Mobile

**La paix dans votre poche.** Application Flutter de sécurité personnelle et de maison connectée : alerte SOS, localisation en direct, alertes, caméras et appareils domestiques.

## Démarrage

```bash
flutter pub get
flutter run                                   # mode démo : données locales, aucun backend
flutter run --dart-define-from-file=env/local.json   # backend Supabase local
flutter test
```

### Avec le backend

La configuration est injectée à la compilation (`lib/core/config/env.dart`). Copier
`env/production.json.example` en `env/<nom>.json` et renseigner l'URL et la clé **publishable/anon**
(jamais la clé `service_role`). Les fichiers `env/*.json` ne sont pas versionnés.

Backend local ([jammtech_backend](https://github.com/ouzking/jammtech_backend)) sur un téléphone branché :

```bash
supabase start && supabase functions serve --env-file supabase/functions/.env   # dans jammtech_backend
adb reverse tcp:55721 tcp:55721      # le téléphone joint le backend via 127.0.0.1
flutter run --dart-define-from-file=env/local.json
```

Comptes de test (mot de passe `JammTech2026!`) : Moussa `77 123 45 67`, Awa `77 000 00 01` (proche de
Moussa). Code de désarmement `1234`, code de contrainte `9999`. En local, les codes SMS s'affichent dans
les journaux de `supabase functions serve`.

Le push nécessite un projet Firebase (`google-services.json`, `GoogleService-Info.plist`) : sans lui,
l'application fonctionne mais n'envoie ni ne reçoit de notifications.

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
│   ├── backend.dart     Client Supabase, erreurs en français
│   ├── repositories/    Accès aux données (Supabase, ou démo sans backend)
│   ├── models.dart      Modèles typés
│   └── demo_data.dart   Données de démonstration
├── services/        Session, push, temps réel, position, verrouillage local
├── screens/         Écrans (coquille à onglets, SOS, carte, alertes, maison, profil…)
├── routes.dart      Routes nommées
└── main.dart
```

## Backend

Le backend (Supabase) est développé dans [ouzking/jammtech_backend](https://github.com/ouzking/jammtech_backend).
Le cahier des charges est dans [docs/BACKEND_PROMPT.md](docs/BACKEND_PROMPT.md).
Le contrat d'API est dans `docs/API.md` du dépôt backend.
