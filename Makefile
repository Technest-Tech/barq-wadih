.PHONY: up down restart logs ps mysql redis backend-install backend-serve backend-test backend-lint frontend-install frontend-dev frontend-build flutter-run flutter-analyze

## ── Docker ───────────────────────────────────────────────────────────────────
up:
	@bash scripts/dev-up.sh

down:
	@bash scripts/dev-down.sh

restart: down up

logs:
	docker compose logs -f

ps:
	docker compose ps

## ── Service Shells ───────────────────────────────────────────────────────────
mysql:
	docker compose exec mysql mysql -u barq_user -p***REMOVED*** barq_wadih

redis:
	docker compose exec redis redis-cli

## ── Backend (Laravel) ────────────────────────────────────────────────────────
backend-install:
	cd backend && composer install

backend-serve:
	cd backend && php artisan serve

backend-test:
	cd backend && php artisan test

backend-lint:
	cd backend && ./vendor/bin/pint --test && ./vendor/bin/phpstan analyse

## ── Frontend (Next.js) ───────────────────────────────────────────────────────
frontend-install:
	cd frontend && npm install

frontend-dev:
	cd frontend && npm run dev

frontend-build:
	cd frontend && npm run build

## ── Mobile (Flutter) ─────────────────────────────────────────────────────────
flutter-run:
	cd mobile && flutter run

flutter-analyze:
	cd mobile && flutter analyze
