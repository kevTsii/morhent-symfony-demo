# Raccourcis pour l'environnement de développement local (Docker Compose)

COMPOSE = docker compose
EXEC = $(COMPOSE) exec -T

# Applications avec Doctrine et PHPUnit (NavetteSimu n'en a pas encore)
PHP_APPS = morhent flottesimu

.PHONY: up reset test

# Démarre tous les services (build inclus)
up:
	$(COMPOSE) up -d --build

# Recrée la base de chaque application, applique les migrations, charge les fixtures
reset:
	@set -e; for app in $(PHP_APPS); do \
		echo "==> $$app"; \
		$(EXEC) $$app bin/console doctrine:database:drop --force --if-exists; \
		$(EXEC) $$app bin/console doctrine:database:create; \
		$(EXEC) $$app bin/console doctrine:migrations:migrate -n --allow-no-migration; \
		$(EXEC) $$app sh -c 'if bin/console list doctrine:fixtures --raw 2>/dev/null | grep -q fixtures:load; then bin/console doctrine:fixtures:load -n; else echo "doctrine-fixtures-bundle absent : fixtures ignorees"; fi'; \
	done

# Lance PHPUnit dans chaque application, comme la CI
test:
	@set -e; for app in $(PHP_APPS); do \
		echo "==> $$app"; \
		$(EXEC) $$app bin/phpunit; \
	done
