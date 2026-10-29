# Morhent : vendre au-dessus d'un logiciel tiers, et tout annuler proprement quand ça casse

Morhent est une application de démonstration. Elle montre comment construire un site de réservation et un back-office **au-dessus d'un logiciel métier existant qui fait foi**, sans dupliquer ses données, et comment **annuler automatiquement** une réservation en plusieurs étapes quand l'une d'elles échoue (saga avec compensation).

- **Démo en ligne** : [https://à-faire]<domaine>
- **Vidéo (7 minutes)** : <lien YouTube>
- **Étude de cas** : [https://à-faire]


> Morhent, FlotteSimu et NavetteSimu sont fictifs. Aucune donnée ne provient d'un vrai loueur ou d'un vrai projet client.

## Le scénario

**Morhent** loue des voitures et des utilitaires en Bretagne depuis trois agences : Rennes Gare, Brest Aéroport et Quimper Centre. Ses réservations, clients, prix et calendrier vivent dans **FlotteSimu**, son logiciel de gestion. Morhent veut vendre en ligne des voyages en plusieurs étapes, avec la navette aéroport de son partenaire **NavetteSimu**, sans recopier FlotteSimu.

Le moment clé : une cliente paie un voyage Rennes → Brest → Quimper avec navette. Le deuxième tronçon échoue côté FlotteSimu. Morhent relance trois fois, puis annule la navette et le premier tronçon dans l'ordre inverse, rembourse la cliente via Stripe et la prévient par e-mail. Le journal de saga montre chaque étape.

## Vocabulaire

### Métier

| Terme                | Sens dans le projet                                                                                                                                                                                                                                  |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Flotte**           | L'ensemble des véhicules d'un loueur (voitures et utilitaires), répartis entre ses agences. En anglais : *fleet*.                                                                                                                                    |
| **FlotteSimu**       | Le logiciel de gestion de flotte de Morhent, simulé pour la démo. Il gère les véhicules, les réservations, les clients, les prix et le calendrier. C'est la **source de vérité** : Morhent ne fait que le consulter et lui envoyer des réservations. |
| **Navette**          | Un transfert routier en minibus ou en van entre l'aéroport de Brest et une adresse (hôtel, gare, centre-ville). Ce n'est pas un bateau : le ferry est hors périmètre.                                                                                |
| **NavetteSimu**      | Le partenaire qui assure ces navettes, simulé pour la démo. Il propose un devis, une réservation et une annulation.                                                                                                                                  |
| **Agence**           | Un point de départ ou de retour des véhicules : Rennes Gare, Brest Aéroport, Quimper Centre.                                                                                                                                                         |
| **Voyage**           | Ce que la cliente achète et paie en une fois : un ou plusieurs tronçons, avec ou sans navette.                                                                                                                                                       |
| **Tronçon**          | Une location d'un véhicule entre une agence de départ et une agence de retour, à des dates données. Exemple : Rennes Gare → Brest Aéroport. Chaque tronçon devient une réservation dans FlotteSimu.                                                  |
| **Catégorie**        | Une famille de véhicules (citadine, break, utilitaire, etc.). La cliente réserve une catégorie, pas un véhicule précis.                                                                                                                              |
| **Agence de retour** | L'agence où le véhicule est rendu. Des règles définissent les retours autorisés depuis chaque agence.                                                                                                                                                |
| **Devis**            | Le prix réel d'un tronçon calculé par FlotteSimu, options comprises, garanti 15 minutes.                                                                                                                                                             |
| **Bon**              | Le récapitulatif envoyé par e-mail à la cliente une fois le voyage confirmé.                                                                                                                                                                         |
| **Correspondances**  | La table qui relie les catégories, agences et options de Morhent à celles de FlotteSimu. Le manager la modifie sans développeur.                                                                                                                     |

### Technique

| Terme                     | Sens dans le projet                                                                                                                                                                                                                                     |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Mode courtier**         | Morhent vend au-dessus de FlotteSimu sans copier ses données : il interroge, réserve et annule à travers son API.                                                                                                                                       |
| **Source de vérité**      | Le système dont les données font foi en cas de désaccord. Ici, FlotteSimu.                                                                                                                                                                              |
| **Saga**                  | Une suite d'étapes (paiement, tronçon 1, tronçon 2, navette) qui doit réussir en entier ou être annulée en entier, sans transaction commune entre les systèmes.                                                                                         |
| **Compensation**          | L'annulation, dans l'ordre inverse, des étapes déjà réussies d'une saga quand une étape échoue, suivie du remboursement.                                                                                                                                |
| **Saga bloquée**          | Une saga dont la compensation n'a pas pu aller au bout (service injoignable). Elle attend une relance par l'administrateur.                                                                                                                             |
| **Idempotence**           | La garantie qu'une même requête envoyée deux fois ne produit qu'un seul effet. Assurée par l'en-tête `Idempotency-Key`.                                                                                                                                 |
| **Relance**               | Une nouvelle tentative après un échec, avec un délai qui augmente à chaque fois (3 tentatives au maximum).                                                                                                                                              |
| **Panneau de pannes**     | L'écran d'administration de FlotteSimu qui permet de provoquer de la latence ou des erreurs pour la démo.                                                                                                                                               |
| **Orchestrateur de saga** | Le composant de Morhent qui fait avancer chaque saga : il envoie un message par étape (Symfony Messenger), suit l'état (Symfony Workflow), décide de l'étape suivante ou de la compensation. C'est le seul à appeler FlotteSimu, NavetteSimu et Stripe. |

## Ce que le projet démontre

| Sujet                        | Mise en œuvre                                                                                            |
|------------------------------|----------------------------------------------------------------------------------------------------------|
| Intégration en mode courtier | Aucune copie du calendrier ni des prix ; FlotteSimu reste la source de vérité                            |
| Saga avec compensation       | Symfony Messenger (un message par étape) + Symfony Workflow, état persisté en base                       |
| Idempotence                  | En-tête `Idempotency-Key` dérivé de la saga et de l'étape ; un message rejoué ne crée jamais de doublon  |
| Résilience                   | 3 tentatives avec délai croissant, cache de 60 s sur les disponibilités, journal de chaque appel externe |
| Paiement                     | Stripe en mode test, remboursement automatique                                                           |
| SSO et rôles                 | Keycloak (OpenID Connect), rôles issus des groupes Keycloak, droits par objet via des Voters             |
| Événements                   | RabbitMQ transporte les événements de FlotteSimu vers le tableau de bord                                 |
| Front-end                    | Twig, Tailwind, Turbo et Stimulus, sans framework JavaScript ni Node                                     |
| Qualité                      | Tests fonctionnels qui rejouent chaque scénario de panne, CI GitHub Actions                              |

## Architecture

```
                 ┌─────────────────────────────┐
 Cliente ───────▶│  Morhent (Symfony)          │
 Équipe  ──SSO──▶│  site + back-office         │◀──── Keycloak (OIDC)
                 │  orchestrateur de saga      │
                 │  PostgreSQL                 │
                 └──────┬──────────┬───────┬───┘
                        │ HTTP     │ HTTP  │ HTTPS
                        ▼          ▼       ▼
                 FlotteSimu   NavetteSimu  Stripe (test)
                 (source de   (partenaire)
                  vérité)
                        │
                        └── événements ──▶ RabbitMQ ──▶ tableau de bord Morhent
```

- **Morhent** : une seule application Symfony qui porte le site client, le back-office et l'orchestrateur de saga.
- **FlotteSimu** : application Symfony séparée, avec sa propre base, qui joue le logiciel tiers. Elle expose un panneau de pannes pour ralentir ou faire échouer les appels à la demande.
- **NavetteSimu** : même modèle en plus court (devis, réservation, annulation).
- seul l'orchestrateur de saga appelle les services externes.

### API de FlotteSimu

| Endpoint                     | Rôle                                                          |
|------------------------------|---------------------------------------------------------------|
| `GET /availability`          | Disponibilités par catégorie, agence et période               |
| `POST /quotes`               | Prix réel d'un tronçon, options comprises, valable 15 minutes |
| `POST /reservations`         | Création, avec en-tête `Idempotency-Key`                      |
| `GET /reservations/{ref}`    | Lecture d'une réservation                                     |
| `DELETE /reservations/{ref}` | Annulation, utilisée par la compensation                      |

Événements publiés sur RabbitMQ : `reservation.created`, `reservation.cancelled`, `vehicle.picked_up`, `vehicle.returned`.

## La saga

Rien n'est créé dans FlotteSimu avant le paiement.

**Flux nominal**

```
Paiement Stripe ─▶ Tronçon 1 ─▶ Tronçon 2 ─▶ Navette ─▶ Confirmé (bon par e-mail)
```

**Flux d'échec** (exemple : échec du tronçon 2 après 3 tentatives)

```
Paiement ─▶ Tronçon 1 ✔ ─▶ Tronçon 2 ✖ (1/3, 2/3, 3/3)
                                   │
            Compensation, ordre inverse :
            annuler la navette (si créée) ─▶ annuler le tronçon 1 ─▶ rembourser ─▶ informer la cliente
```

Si FlotteSimu reste injoignable pendant la compensation, la saga passe à l'état **Bloqué** et apparaît dans le back-office, où l'administrateur peut la relancer.

## Démarrage rapide

Prérequis : Docker et Docker Compose, Git. Pour le paiement, un compte Stripe en mode test.

```bash
git clone https://github.com/<compte>/morhent.git
cd morhent
cp .env.dist .env            # renseigner les clés Stripe de test
docker compose up -d
docker compose exec morhent bin/console doctrine:migrations:migrate -n
docker compose exec morhent bin/console doctrine:fixtures:load -n
docker compose exec flottesimu bin/console doctrine:fixtures:load -n
```

`docker compose up` lance Morhent, FlotteSimu, NavetteSimu, PostgreSQL, RabbitMQ, Keycloak, les workers Messenger et Mailpit. Les adresses locales de chaque service sont indiquées dans `docker-compose.yml`.

En local, **Mailpit** capture tous les e-mails : rien ne part réellement.

### Paiement de test

Utiliser une [carte de test Stripe](https://docs.stripe.com/testing), par exemple `4242 4242 4242 4242`, une date future et n'importe quel CVC.

### Comptes de démo

| Persona        | Rôle                   | Accès                                                                |
|----------------|------------------------|----------------------------------------------------------------------|
| Léa Morvan     | Cliente                | Site de réservation                                                  |
| Yann Le Goff   | Agent, agence de Brest | Départs et retours du jour, réservation au comptoir                  |
| Claire Daniel  | Manager                | Tableau de bord, CA par agence et agent, correspondances, export CSV |
| Erwan Kerhervé | Administrateur         | Journal des sagas, appels FlotteSimu, panneau de pannes              |

Les identifiants sont créés par l'import du realm Keycloak (`docker/keycloak/`). Sur la démo en ligne, les comptes sont remis à zéro chaque nuit.

## Reproduire la panne

1. Se connecter en tant qu'**Erwan Kerhervé** (admin).
2. Ouvrir le **panneau de pannes** et activer « Échec forcé sur la prochaine création ».
3. Réserver un voyage en deux tronçons avec navette et payer avec une carte de test.
4. Ouvrir le **journal de saga** : relances du tronçon 2, puis compensation en violet, remboursement Stripe.
5. Vérifier l'e-mail de remboursement dans Mailpit.

Autres réglages du panneau : latence de 0 à 5 s, taux d'erreur aléatoire, indisponibilité totale. En ligne, le panneau n'affecte que la session du visiteur.

## Tests

```bash
docker compose exec morhent bin/phpunit
```

Les tests fonctionnels rejouent quatre scénarios : échec au tronçon 1, échec au tronçon 2, échec à la navette, succès complet. Ils vérifient l'ordre de compensation, l'absence de doublon en cas de message rejoué et le remboursement.

La CI GitHub Actions lance les tests et l'analyse statique à chaque push, puis déploie la branche principale.

## Structure du dépôt

```
apps/
  morhent/        site client, back-office, orchestrateur de saga
  flottesimu/     logiciel de gestion simulé et panneau de pannes
  navettesimu/    partenaire navette simulé
docker/           configuration Keycloak, RabbitMQ, reverse proxy
docs/             schémas, captures, GIF de la panne
.github/workflows CI et déploiement
```

## Stack

- PHP 8, Symfony (Messenger, Workflow, Security, Mailer)
- Doctrine, PostgreSQL
- RabbitMQ
- Keycloak (OpenID Connect)
- Twig, Tailwind (`symfonycasts/tailwind-bundle`), Symfony UX Turbo et Stimulus, AssetMapper
- Turbo Streams + Mercure (en option) pour le journal de saga et le tableau de bord en direct
- Chart.js, icônes Lucide
- Stripe (mode test)
- Docker Compose, GitHub Actions

## Choix et limites

- **Pas de copie de FlotteSimu.** La base de Morhent ne garde que ce que FlotteSimu ne gère pas : voyages, tronçons, commandes partenaires, sagas, journal des appels, correspondances et miroir minimal des utilisateurs.
- **Back-office fait maison** plutôt qu'un CRM existant, pour que le code soit lisible et démontrable.
- **Hors périmètre** : blog, référencement, espace client complet, plusieurs fournisseurs par service.

## Auteur

**Kevin Tsiory Rakotosoa** (Tsiory), développeur fullstack PHP / Symfony senior, en télétravail pour des clients français et européens.

- Site : [kevin-tsiory-rakotosoa.pages.dev](https://kevin-tsiory-rakotosoa.pages.dev/)
- Contact : [tsioryrakotosoa@gmail.com](mailto:tsioryrakotosoa@gmail.com)
- LinkedIn : [kevin-tsiory-rakotosoa](https://www.linkedin.com/in/kevin-tsiory-rakotosoa-7951931a6/)
