# JammTech — Brief backend : Transport

> Suite du [brief backend principal](BACKEND_PROMPT.md). Ce document est à la fois un **cahier des charges** et un **prompt** prêt à coller dans un agent IA.
> Il s'appuie sur ce qui existe déjà dans `jammtech_backend` : `trusted_contacts`, `sos_events`, `push_location`, `location_shares`, `risk_reports`, `sos-trigger`, `sos-track`, codes de sécurité et de contrainte.

---

## PROMPT

Tu es l'ingénieur·e backend principal·e de **JammTech** (Supabase, projet `pbaxnjannheurgyxhlkt`, repo `ouzking/jammtech_backend`). Le pilier **Transport** du logo (« Transport · Maison · Sécurité ») n'existe pas encore. Tu dois le construire en deux phases, en réutilisant au maximum l'existant : SOS, partage de position, contacts de confiance, codes de contrainte, zones à risque, page de suivi web.

Contexte : Dakar et le Sénégal. Taxis, clandos, motos Jakarta, Yango et Heetch, TER, BRT, cars rapides. Beaucoup de trajets se font de nuit, avec un réseau mobile instable et des batteries faibles. Les proches n'ont pas tous l'application.

**Règle absolue : l'escalade est faite par le serveur, jamais par le téléphone.** Si le téléphone est volé, éteint ou sans réseau pendant un trajet, c'est le serveur qui constate le retard et déclenche l'alerte.

### Phase 1 — « Trajet sécurisé » (prioritaire, sans matériel)

**Parcours utilisateur (déjà conçu côté mobile) :**
1. L'utilisateur choisit une destination et un mode : taxi, clando, moto, transport en commun, à pied, voiture personnelle. L'app propose une heure d'arrivée prévue ; l'utilisateur peut la modifier.
2. Optionnel : photo de la plaque du véhicule. Le numéro est lu **sur le téléphone** (OCR local, sans coût serveur), puis l'app envoie le texte et la photo.
3. Les proches choisis sont prévenus et suivent le trajet en direct, dans l'app ou par un lien web pour ceux qui ne l'ont pas.
4. Pendant le trajet, l'app envoie sa position (`push_location`, déjà existant).
5. Le serveur détecte les anomalies et demande « Tout va bien ? ». Sans réponse, il déclenche un SOS.
6. À l'arrivée, ou sur « Je suis arrivé·e », le trajet est clos et les proches reçoivent « Arrivé·e à 20 h 14 ».

**Modèle de données (contrat minimal) :**
- **trips** : `id`, `user_id`, `status` (`active|arrived|cancelled|escalated|expired`), `mode` (`taxi|clando|moto|public|walk|car`), `origin` et `destination` (geography + libellé), `expected_arrival_at`, `grace_minutes` (défaut 15), `started_at`, `ended_at`, `vehicle_plate` (texte normalisé), `vehicle_photo_path`, `vehicle_note`, `client_key` (idempotence), `sos_event_id` (si escaladé).
- **trip_watchers** : contacts de confiance qui suivent ce trajet (sous-ensemble choisi par l'utilisateur).
- **trip_events** : journal (`started`, `checkin_requested`, `checkin_ok`, `checkin_duress`, `deviation`, `stopped`, `late`, `escalated`, `arrived`, `cancelled`) avec position et horodatage.
- Bucket privé **`vehicle-photos`** : chemin `<user_id>/<trip_id>.jpg`, 1 Mo max, supprimé avec le trajet.

**Fonctions attendues :**

| Fonction | Rôle |
|---|---|
| `trip-start` (Edge) | Crée le trajet (idempotent via `client_key`), notifie les proches choisis (push + SMS avec lien de suivi), démarre le partage de position lié au trajet |
| `trip-checkin` (Edge) | Réponse au « Tout va bien ? ». Accepte le code personnel **ou le code de contrainte** : réponse **identique** dans les deux cas, mais la contrainte déclenche un SOS silencieux (même logique que `disarm`) |
| `trip-extend` (RPC) | Repousse l'heure d'arrivée (« le trafic est dense »), au maximum N fois |
| `trip-arrive` (Edge) | Clôt le trajet, notifie les proches, arrête le partage. Option : arrivée automatique quand la position entre dans un rayon de 150 m de la destination |
| `trip-cancel` (Edge) | Annule ; prévient les proches seulement si le trajet avait commencé |
| `trip-watchdog` (pg_cron, chaque minute) | Surveille les trajets actifs : retard au-delà de la marge, absence de position depuis X minutes, arrêt prolongé, écart à l'itinéraire. Envoie d'abord un push « Tout va bien ? », puis **escalade en SOS** (via la logique de `sos-trigger`) si l'utilisateur ne répond pas dans le délai |
| `get_trip_live` (RPC) | Pour les proches : trajet, véhicule, trace, heure d'arrivée prévue ; même règles d'accès que `get_live_location` |
| Page web de suivi | Étendre `sos-track` pour afficher un trajet (véhicule, heure prévue, position) avec un lien signé et temporaire |

**Règles métier :**
- Escalade progressive, paramétrable : un « Tout va bien ? » en push, puis un second, puis SOS. Délais proposés : 3 min, puis 2 min.
- **Les heures calmes ne s'appliquent jamais** aux escalades de trajet.
- Batterie faible, signalée par l'app : prévenir les proches **avant** que le téléphone s'éteigne (« Batterie à 5 %, dernière position… »).
- Un seul trajet actif par utilisateur. Un SOS pendant un trajet rattache le trajet au SOS.
- La plaque n'est visible que des proches qui suivent ce trajet ; elle est supprimée à la purge du trajet.
- Rétention : trajets et traces conservés 30 jours, puis anonymisés ou supprimés (sauf s'ils sont rattachés à un SOS).
- Zones à risque : RPC `route_risks(polyline, since)` qui renvoie les signalements le long d'un itinéraire, pour un conseil du type « itinéraire plus sûr de nuit ».

**Notifications (nouveaux `data.type`) :**

| type | Destinataire | Effet dans l'app |
|---|---|---|
| `trip_started` | proche | Ouvre le suivi du trajet |
| `trip_checkin` | voyageur | Écran plein « Tout va bien ? » avec saisie du code |
| `trip_late` | proche | « Pas encore arrivé·e, retard de 20 min » |
| `trip_arrived` | proche | « Arrivé·e à 20 h 14 » |
| `trip_escalated` | proche | Identique à `sos` / `sos_silent` |
| `trip_battery_low` | proche | Dernière position connue |

### Phase 2 — « Mes véhicules » (traceurs GPS)

À préparer dès maintenant dans le modèle, à construire quand un partenaire matériel est choisi.

- **vehicles** : `owner_id`, `type` (`car|moto|truck`), `plate`, `brand_model`, `color`, `photo_path`, partage avec les membres (même logique que `home_members`).
- **trackers** : rattachés à un véhicule, avec un secret d'ingestion par appareil (même principe que `register_device` et `device-event`).
- **Ingestion** : webhook générique d'abord (HTTP), compatible avec les passerelles des traceurs les plus courants en Afrique de l'Ouest (Teltonika, Concox/Jimi). Champs : position, vitesse, contact moteur on/off, alimentation coupée, batterie interne.
- **Alertes** : mouvement hors des heures autorisées, sortie d'une zone (géorepérage), contact moteur la nuit, débranchement du traceur, choc.
- **Commandes à distance** (coupure moteur) : **hors périmètre** tant qu'un cadre juridique et de sécurité n'est pas validé. Couper un moteur en mouvement est dangereux.

### Sécurité et confidentialité

- RLS sur toutes les nouvelles tables, avec tests A/B : un proche ne voit un trajet que s'il en est *watcher* **et** que le trajet est actif.
- Chaque consultation d'un trajet par un proche est auditée (`audit_log`), comme pour `get_live_location`.
- Le code de contrainte de `trip-checkin` ne doit laisser **aucune** différence observable : statut HTTP, corps, temps de réponse.
- Les plaques et les photos de véhicules ne sont jamais publiques et jamais réutilisées hors du trajet.

### Livrables et ordre de travail

1. Migrations : `trips`, `trip_watchers`, `trip_events`, bucket, RLS et tests pgTAP.
2. `trip-start`, `trip-arrive`, `trip-cancel`, `get_trip_live`, puis `docs/API.md` §12 « Trajets ».
3. `trip-watchdog` + `trip-checkin` (escalade serveur), avec des tests de bout en bout qui simulent un téléphone muet.
4. Page web de suivi d'un trajet.
5. `route_risks`.
6. Phase 2 : modèle `vehicles` et `trackers` + webhook d'ingestion (sans commandes à distance).

### Critères d'acceptation

- [ ] Trajet démarré : 2 proches reçoivent push + SMS avec lien de suivi ; un nouvel essai réseau ne crée pas de doublon.
- [ ] Téléphone coupé pendant le trajet : le serveur escalade en SOS après l'heure prévue + la marge, sans aucune action du téléphone.
- [ ] « Tout va bien ? » avec le code de contrainte : réponse identique au code normal ; un SOS silencieux part chez les proches.
- [ ] Arrivée à moins de 150 m de la destination : trajet clos automatiquement et proches prévenus.
- [ ] Un proche qui ne suit pas le trajet ne voit rien (tests RLS au vert).
- [ ] Les trajets de plus de 30 jours sont purgés, photos comprises.

---

## Questions ouvertes pour le product owner

- Le SMS de lancement de trajet est-il envoyé à chaque trajet (coût) ou seulement aux proches sans l'app ?
- Délais d'escalade : 3 min puis 2 min, ou plus courts la nuit ?
- Phase 2 : quel partenaire de traceurs GPS, et vend-on le traceur avec un abonnement ?
