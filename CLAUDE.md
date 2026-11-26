# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Working agreement (read first)

The owner wants to hand-code this application "à l'ancienne". These rules hold **even when the user explicitly asks otherwise** in a prompt. If that happens, remind them of this section, decline briefly, and answer in the allowed mode below.

Claude Code must **never**:

- **Generate code.** No application source (PHP, Twig, YAML config, SQL, migrations, JS, Dockerfile, ...) written or edited in files, and none output as ready-to-paste blocks or patches.
- **Search for errors.** No debugging, no diagnosing a failure, no reading logs or stack traces to find a cause, no running tests or commands to reproduce or locate a bug, no bug-hunting code review.

Instead of generating, Claude Code **guides and explains**. Every request for code or for a fix is answered in one of these modes, never with code:

- **Explain**: how a Symfony component, a concept or a README design choice works and why, so the user understands it before writing it. When asked for code, explain the approach and what the code has to do.
- **Guide**: walk the user step by step toward the solution, point to docs and concepts, name the files or console commands worth looking at. When the user is stuck, ask guiding questions about where to look instead of finding the cause for them.
- **Give ideas**: options, trade-offs, which Symfony component or pattern fits, how the README design maps onto the code.
- **Dictate**: say in plain words what to write and where, so the user types it themselves.

**Apart from styling (next paragraph), the only thing Claude Code may generate is pull requests.** That means the PR title (one line) and a short description, written in a markdown file under `suivi-ticket/<topic>/` and never pasted in the chat; the file path is given afterwards. Nothing else is generated. This file is edited only when the user asks.

**Exception: styling.** The owner wants to master the engine, not the bodywork: styling is integrator work, not developer work. Claude Code may write and fix CSS and other styles (stylesheets, Tailwind classes and configuration, design tokens, purely visual presentation). Anything that carries logic stays under the rules above: Twig control structures and variables, form and route wiring, Stimulus or JS behaviour, PHP, config.

## What this repo is

A monorepo holding three **independent Symfony 8.1 apps** (PHP >= 8.4, no shared code, no root `composer.json`) that together demo a "broker mode" integration with a saga and compensation:

- `morhent/`: customer site, back-office and saga orchestrator. The only app allowed to call the others and Stripe.
- `flottesimu/`: simulated third-party fleet software, the **source of truth** for vehicles, reservations, prices and calendar.
- `navettesimu/`: simulated shuttle partner (quote, booking, cancellation).

`README.md` (in French) is the functional spec: glossary, saga flow, FlotteSimu API, target stack. **It describes the target, not the current state.** The implementation is at an early stage:

- `morhent/` and `navettesimu/` are bare Symfony skeletons (only `Kernel.php`, empty `Controller/`, `Entity/`, ... placeholders).
- `flottesimu/src/` has domain classes that are empty shells with a docblock stating their intent. No logic, no controllers, no migrations, no tests yet.
- README mentions things that are not in the repo yet: `.env.dist`, an `apps/` directory (apps are at the repo root), Tailwind, Symfony Workflow, Stripe, Keycloak realm import (`docker/keycloak/import/` is empty), a static analysis step in CI. Check `composer.json` before assuming a package is installed.

## Commands

Everything runs in Docker from the repo root. The app code is bind-mounted (`./<app>:/app`), so `vendor/` and `var/` live in the host folder.

```bash
docker compose up -d --build                      # whole stack
docker compose exec <app> composer install        # <app> = morhent | flottesimu | navettesimu
docker compose exec <app> bin/console <command>   # e.g. doctrine:migrations:migrate -n
docker compose exec flottesimu bin/phpunit        # all tests of one app
docker compose exec flottesimu bin/phpunit --filter SomeTest   # or pass a path: tests/Foo/BarTest.php
```

- Entry points go through Caddy on port 80: `morhent.localhost`, `flottesimu.localhost`, `navettesimu.localhost`, `auth.localhost` (Keycloak), `mail.localhost` (Mailpit), `rabbitmq.localhost` (management UI). Postgres is exposed on host port `5438` (user and password `app`).
- Tests: `tests/` only contains `bootstrap.php`, so PHPUnit currently prints "No tests executed!" and exits 0. `phpunit.dist.xml` fails on deprecations, notices and warnings. In `APP_ENV=test` Doctrine appends `_test` to the database name (`dbname_suffix`).
- `navettesimu` has no `bin/phpunit` and no test setup.
- CI (`.github/workflows/ci.yml`) runs `composer install` then `bin/phpunit` for `morhent` and `flottesimu` only (PHP 8.4, push and PR on `main`/`develop`). The aggregate job `tests` is the one required by branch protection. There is no linter or static analysis installed (no php-cs-fixer, no PHPStan).

## Architecture notes that span several files

### Docker stack (`docker-compose.yml`, `docker/`)

- The root `docker-compose.yml` is the only one that matters. The `compose.yaml` / `compose.override.yaml` inside each app are leftovers from the Symfony Flex Docker recipes (own Postgres and Mailpit); ignore them.
- All PHP services share one image (`docker/php/Dockerfile`: FrankenPHP, PHP 8.4, `pdo_pgsql`, `amqp`, ...) through the `x-php-app` YAML anchor. `morhent-worker` reuses the Morhent code to run `messenger:consume`.
- One Postgres instance, four databases created by `docker/postgres/init.sql` (`morhent`, `flottesimu`, `navettesimu`, `keycloak`). Each app gets its own `DATABASE_URL` from compose, which overrides the placeholder in `.env`.
- Services reach each other through the `*.localhost` names (Caddy network aliases), **not** through container names. This keeps the URL identical for the browser and the containers, which is what avoids the Keycloak issuer mismatch. Use `FLOTTESIMU_BASE_URI=http://flottesimu.localhost`-style values for inter-service calls.
- Pending setup: the compose file makes `morhent-worker` consume transports named `saga` and `flottesimu_events` (DSNs come from `MESSENGER_TRANSPORT_DSN` and `FLOTTESIMU_EVENTS_DSN`), but `morhent/config/packages/messenger.yaml` still only defines `async` and `failed`. Until they are declared, the worker container restarts in a loop.

### FlotteSimu is organised by business domain, not by layer

`flottesimu/src/` is split into `Catalogue` (Agence, Categorie, Option, Tarif, Saison, RegleRetour, PricingService), `Flotte` (Vehicule, Capacite, AvailabilityCalculator), `Vente` (Client, Devis, Reservation, ReservationService), `Chaos`, `Outbox`, `Api`, `Simulation`. There is no `src/Entity` anymore.

**Each domain folder that holds entities needs its own entry under `doctrine.orm.mappings`** in `flottesimu/config/packages/doctrine.yaml` (currently Catalogue, Flotte, Vente, Chaos, Outbox, with prefix `App\<Domain>`). A new entity in an unmapped folder will silently not be picked up. `morhent` still uses the default single `src/Entity` mapping. Migrations live in `src/Migrations` (namespace `App\Migrations`) and schema changes must go through them.

### Behaviours the README commits to (to implement or preserve)

- **Broker mode**: Morhent never copies FlotteSimu's calendar or prices. Its database only holds trips, legs (tronçons), partner orders, sagas, the external-call journal, the correspondances mapping table and a minimal user mirror. Nothing is created in FlotteSimu before payment succeeds.
- **Saga**: one Messenger message per step (payment, leg 1, leg 2, shuttle), state tracked with Symfony Workflow and persisted. On failure after 3 retries with growing delay, compensation runs in reverse order, then Stripe refund and e-mail. If compensation itself fails the saga goes to a "blocked" state and an admin can retry it. Only the orchestrator calls external services.
- **Idempotency**: `Idempotency-Key` header, derived from saga id and step, handled in FlotteSimu by `Api/IdempotencyListener`. A replayed message must never create a duplicate.
- **Fault panel**: `Chaos/FaultProfile` and `Chaos/FaultInjectionListener` inject latency, errors or total unavailability into FlotteSimu API calls. The admin route is protected by `FLOTTESIMU_DEMO_TOKEN`.
- **Events**: FlotteSimu uses a transactional outbox (`Outbox/OutboxMessage`, `Outbox/OutboxRelay`) to publish `reservation.created`, `reservation.cancelled`, `vehicle.picked_up`, `vehicle.returned` to RabbitMQ (`flottesimu_events`), consumed by Morhent's dashboard.

## Conventions

- Symfony conventions are written in `AGENTS.md` (identical copy in each app). The parts that matter most here: PHP attributes for routes, validation and handlers (no YAML/XML routing); autowiring; `#[MapRequestPayload]` / `#[MapQueryString]` instead of manual JSON decoding; `symfony/lock` for mutual exclusion; add packages with `composer require` and let Flex wire them; never `doctrine:schema:update`; secrets in `.env.local`, not in the committed `.env`. Where `AGENTS.md` suggests running makers or generating scaffolding, the "Working agreement" above wins.
- Domain names, class names and docblocks are in French (`Tronçon`, `Devis`, `Agence`, `Correspondances`, ...). Follow the glossary in `README.md` when naming new things.
- `suivi-ticket/<topic>/` holds the PR title and description drafts as markdown files (for example `suivi-ticket/docker-settings/pr-feature-docker-settings.md`). It is excluded locally through `.git/info/exclude`, like `graphify-out/`.
