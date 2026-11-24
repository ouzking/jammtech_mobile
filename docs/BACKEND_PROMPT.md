# JammTech — Brief backend (Supabase)

> Ce document sert à la fois de **cahier des charges** pour l'équipe backend et de **prompt** prêt à coller dans un agent IA (Claude Code, etc.).
> Tout ce qui suit est déduit de l'application mobile existante : [ouzking/jammtech_mobile](https://github.com/ouzking/jammtech_mobile).

---

## PROMPT

Tu es l'ingénieur·e backend principal·e de **JammTech**, une application mobile de **sécurité personnelle et de maison connectée** destinée au marché **sénégalais** (slogan : « La paix dans votre poche »). L'application Flutter est déjà construite, avec des données simulées. Ta mission : concevoir et livrer un backend **Supabase** de qualité production qui remplace ces données simulées, sans modifier l'expérience utilisateur.

Ce produit protège des personnes en danger. **La fiabilité, la sécurité des données et la latence du SOS passent avant tout le reste.** En cas de doute, choisis l'option la plus sûre, puis documente ton choix.

### 1. Contexte technique

- **Supabase** : projet `pbaxnjannheurgyxhlkt` (déjà créé, vide).
- **Repo backend** : `github.com/ouzking/jammtech_backend` (vide). Tout doit y être versionné : migrations SQL, politiques RLS, Edge Functions, seeds, configuration. **Aucune modification manuelle dans le dashboard qui ne serait pas reproduite par une migration.**
- **Client** : Flutter, avec `supabase_flutter`. Le client n'utilise **que la clé `anon`**. La clé `service_role` ne doit jamais quitter le serveur (Edge Functions, secrets).
- **Langue** : les messages destinés à l'utilisateur sont en **français** (le wolof et l'anglais viendront ensuite).
- **Téléphones** : format E.164, indicatif `+221`. Mobiles : 9 chiffres commençant par 7 ; fixes : par 3.
- **Fuseau horaire** : stockage en UTC (`timestamptz`), affichage en `Africa/Dakar` côté client.

### 2. Fonctionnalités à servir (vues depuis l'app)

| Écran de l'app | Besoin backend |
|---|---|
| Inscription / connexion | Auth **téléphone + mot de passe**, téléphone vérifié par **OTP SMS** |
| Mot de passe oublié (3 étapes) | Envoi d'un OTP SMS (code à 6 chiffres, renvoi possible après 30 s), vérification, puis nouveau mot de passe |
| Accueil | Résumé : état de protection, nombre de caméras en ligne, nombre de proches, alertes récentes |
| **SOS** | Création d'un événement SOS, notification **immédiate** des proches (push + SMS de secours), partage de position en direct, clôture par « Je suis en sécurité » |
| Carte | Position en direct (ajoutée toutes les ~10 m), partage on/off avec les proches |
| Alertes | Liste filtrable (toutes / à traiter / critiques / traitées), détail, marquer comme traitée / rouvrir, tout marquer comme traité |
| Maison | Mode d'armement (Désarmé / Présence / Absence), caméras, appareils (caméras, sirène, éclairage, serrure) avec état on/off |
| Enregistrements | Vidéos par caméra, filtre « mouvement », suppression, **conservation 30 jours** |
| Profil | Nom, téléphone, avatar, compteurs (alertes, proches, appareils), contacts de confiance |
| Paramètres | Langue, position précise, position en arrière-plan, partage automatique en SOS, vidéos en Wi-Fi uniquement, statistiques anonymes |
| Sécurité | PIN et biométrie (gérés **en local** sur l'appareil), double authentification, **code de contrainte**, appareils connectés |
| Notifications | Préférences par type (intrusions, zones, appareils, proches), son, vibration, heures calmes (début / fin) |

### 3. Modèle de données attendu

Conçois le schéma toi-même : celui-ci est le **contrat minimal** utilisé par l'app. Ajoute index, contraintes et clés étrangères selon les règles de l'art.

- **profiles** (1–1 avec `auth.users`) : `full_name`, `phone` (unique, E.164), `avatar_url`, `language` (`fr|wo|en`), `created_at`.
- **trusted_contacts** : `owner_id`, `name`, `relation`, `phone`, `contact_user_id` (nullable : un proche peut ne pas avoir l'app), `priority`. Maximum 5 par utilisateur.
- **homes** : `owner_id`, `name` (ex. « Résidence principale »), `arm_mode` (`disarmed|home|away`), `arm_mode_changed_at`, `arm_mode_changed_by`. Prévoir le partage d'une maison entre plusieurs membres (`home_members` avec rôle `owner|member`).
- **devices** : `home_id`, `type` (`camera|siren|light|lock|sensor`), `name`, `room`, `is_on`, `is_online`, `last_seen_at`, `firmware_version`.
- **security_alerts** : `user_id` / `home_id`, `title`, `description`, `severity` (`critical|warning|info`), `location_label`, `location` (geography, nullable), `device_id` (nullable), `recording_id` (nullable), `resolved_at`, `resolved_by`, `created_at`.
- **recordings** : `home_id`, `device_id` (caméra), `title`, `storage_path`, `thumbnail_path`, `duration_seconds`, `motion_detected`, `started_at`, `expires_at` (= +30 jours).
- **sos_events** : `user_id`, `status` (`active|resolved|cancelled`), `trigger` (`button|duress_code`), `started_at`, `resolved_at`, `last_location` (geography), `silent` (bool).
- **sos_notifications** : `sos_event_id`, `contact_id`, `channel` (`push|sms`), `status` (`queued|sent|delivered|failed`), `error`, `sent_at`.
- **location_shares** / **location_points** : session de partage (`user_id`, `started_at`, `ended_at`) et points (`lat`, `lng`, `accuracy_m`, `recorded_at`). Purge automatique des points après une durée à définir (proposer 7 jours, sauf ceux rattachés à un SOS).
- **risk_reports** (zones à risque) : `location` (geography), `category`, `description`, `reported_by`, `created_at`, `expires_at`. Requête « incidents à moins de 500 m depuis 1 h ».
- **notification_preferences** : un booléen par type et canal, `quiet_hours_start`, `quiet_hours_end`.
- **user_settings** : les réglages listés plus haut.
- **push_tokens** : `user_id`, `token`, `platform` (`android|ios|web`), `updated_at`.

Active **PostGIS** pour tout ce qui est géographique.

### 4. Règles métier critiques

1. **Le flux SOS doit être sans faille.**
   - Le maintien de 3 s et le compte à rebours de 5 s sont gérés par l'app. Le backend reçoit un SOS déjà **confirmé**.
   - Une Edge Function `sos-trigger` crée l'événement et notifie **tous** les proches en parallèle : push d'abord, **SMS en secours systématique** (on ne peut pas compter sur la data mobile). Chaque envoi est journalisé dans `sos_notifications`.
   - **Objectif : moins de 3 s** entre l'appel et l'envoi des notifications. L'opération doit être **idempotente** (une clé fournie par le client empêche un double envoi en cas de nouvelle tentative réseau).
   - Pendant un SOS actif, la position est diffusée en temps réel aux proches (Realtime), et la page de suivi reste consultable par un proche sans l'app (lien SMS signé et temporaire).
   - « Je suis en sécurité » clôt l'événement et prévient les proches.
   - **Les heures calmes ne s'appliquent jamais aux SOS.**
2. **Code de contrainte** : code secret distinct du PIN, stocké **haché** côté serveur. Saisi à la place du code de désarmement, il renvoie une réponse **identique à un désarmement réussi**, mais déclenche un SOS `silent = true`. Aucune trace visible côté appareil.
3. **Mode d'armement** : son changement est journalisé (qui, quand, depuis quel appareil). Un passage à `away` vérifie l'état des capteurs et renvoie les éventuels avertissements (porte ouverte, caméra hors ligne).
4. **Alertes** : générées par les appareils (webhook / Edge Function `device-event`) et par le système (caméra hors ligne, mise à jour). Les notifications respectent les préférences et les heures calmes, **sauf `critical`**.
5. **Vidéos** : bucket privé, accès uniquement par **URL signée** de courte durée. Suppression automatique à `expires_at` (tâche planifiée `pg_cron`). La suppression d'une vidéo supprime aussi le fichier et sa miniature.
6. **Avatars** : bucket `avatars`, 600 px max, l'utilisateur ne peut écrire que dans son propre dossier.
7. **Compteurs de l'app** (alertes non traitées, caméras en ligne, etc.) : exposés par une **vue** ou une **RPC** unique (`get_dashboard()`) pour éviter plusieurs allers-retours sur réseau mobile.

### 5. Sécurité et confidentialité (non négociable)

- **RLS activée sur 100 % des tables**, sans exception. Écris un test pour chaque politique : un utilisateur A ne peut ni lire ni modifier les données de B. Un proche ne voit la position d'un utilisateur **que** pendant un partage actif ou un SOS actif.
- Les données de position sont sensibles : rétention minimale, aucune position dans les logs, accès audité.
- Les SMS OTP sont limités en fréquence (par numéro **et** par IP) pour éviter l'abus et l'explosion des coûts.
- Secrets (fournisseur SMS, FCM/APNs) uniquement dans les **secrets Supabase**, jamais dans le repo.
- Validation stricte des entrées dans toutes les Edge Functions (schéma, longueur, format E.164).
- Préparer un endpoint de **suppression de compte** complète (exigence App Store / Play Store) et d'export des données personnelles.

### 6. Intégrations à choisir (proposer, comparer, justifier)

- **SMS** (OTP + secours SOS) : fournisseur fiable au Sénégal, couvrant Orange, Free et Expresso (comparer Twilio, Vonage, Africa's Talking, Orange SMS API). Critères : délivrabilité, coût, latence.
- **Push** : Firebase Cloud Messaging (Android + iOS via APNs).
- **Caméras / appareils** : définir une interface d'ingestion générique (webhook authentifié par appareil) sans dépendre d'un fabricant. Le flux vidéo en direct est hors périmètre de la v1, mais l'architecture doit l'anticiper.

### 7. Livrables

1. `supabase/migrations/*` : schéma complet, index, RLS, triggers, `pg_cron`.
2. `supabase/functions/*` : au minimum `sos-trigger`, `sos-resolve`, `device-event`, `send-notification`, `delete-account`.
3. `supabase/seed.sql` : données de démo équivalentes à celles de l'app (`lib/data/demo_data.dart` dans le repo mobile).
4. **Tests** : tests RLS (pgTAP) et tests des Edge Functions.
5. **CI GitHub Actions** : lint, tests, puis déploiement des migrations et fonctions sur `main`. Un environnement **staging** séparé de la production.
6. **Contrat API pour l'équipe mobile** : liste des tables, vues, RPC et fonctions, avec exemples de requêtes `supabase_flutter` et types de retour. L'app a des marqueurs `// TODO` aux endroits à brancher.
7. `README.md` : installation locale (`supabase start`), variables d'environnement, déploiement, procédure de restauration de sauvegarde.

### 8. Critères d'acceptation

- [ ] Un nouvel utilisateur s'inscrit avec son numéro +221, reçoit l'OTP et se connecte.
- [ ] Un SOS déclenché notifie 3 proches en push **et** SMS en moins de 3 s ; chaque envoi est tracé.
- [ ] Un proche suit la position en direct pendant le SOS, puis perd l'accès dès sa clôture.
- [ ] Le code de contrainte est indiscernable d'un désarmement normal et déclenche un SOS silencieux.
- [ ] Un utilisateur ne peut accéder à **aucune** donnée d'un autre utilisateur (tests RLS au vert).
- [ ] Les vidéos de plus de 30 jours disparaissent automatiquement, fichiers compris.
- [ ] La suppression de compte efface toutes les données et tous les fichiers de l'utilisateur.
- [ ] Toute la configuration est reproductible depuis le repo, sur un projet Supabase vierge.

### 9. Méthode de travail

1. Commence par **proposer l'architecture** : schéma (diagramme), liste des RPC et fonctions, choix des fournisseurs. Signale les zones d'incertitude **avant** d'écrire du code.
2. Livre par incréments testables, dans cet ordre : Auth et profils → contacts → **SOS** → position → maison et appareils → alertes → vidéos → notifications → conformité.
3. À chaque incrément : migration, RLS, tests, documentation du contrat API.
4. Ne prends aucune décision irréversible (suppression de données, choix d'un fournisseur payant) sans validation du product owner.

---

## Questions ouvertes pour le product owner

- Budget mensuel SMS acceptable ? (Il conditionne le SMS de secours systématique.)
- Un proche sans l'app doit-il pouvoir suivre un SOS via un lien web ?
- Durée de conservation des positions hors SOS ?
- Quels modèles de caméras et capteurs seront supportés en premier ?
- Abonnement payant prévu (stockage vidéo étendu, plus de proches) ?
