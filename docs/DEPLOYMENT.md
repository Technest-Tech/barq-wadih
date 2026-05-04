# Barq Wadih — Production Deployment Documentation

> **Last updated:** 2026-04-25  
> **Deployed by:** Antigravity AI  
> **Status:** ✅ LIVE

---

## 🌐 Live URLs

| URL | Purpose |
|-----|---------|
| https://barqwadih.com | Frontend (Next.js) — main website |
| https://www.barqwadih.com | Frontend redirect |
| https://api.barqwadih.com | Backend API (Laravel) — used by mobile app |

---

## 🏗️ Server Architecture

```
DigitalOcean Droplet (Ubuntu 24.04 LTS)
IP: 192.81.212.150

Nginx (reverse proxy)
  barqwadih.com     → :3000 (Next.js via PM2)
  api.barqwadih.com → PHP-FPM (Laravel)

Next.js (PM2 :3000)    Laravel 12 (PHP 8.3-FPM)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
         MySQL 8         Redis 7        Meilisearch
         (Docker)        (Docker)        (Docker)
```

---

## 📦 Stack Summary

| Component | Version | How it runs |
|-----------|---------|-------------|
| Ubuntu | 24.04 LTS | Droplet OS |
| Nginx | 1.24 | System service |
| PHP | 8.3 | System (php8.3-fpm) |
| Composer | 2.9.7 | System |
| Node.js | 20.x | System |
| PM2 | 6.0.14 | Manages Next.js process |
| Supervisor | system | Manages Laravel queue workers |
| Docker | 29.4.1 | Runs MySQL, Redis, Meilisearch |
| Docker Compose | v5.1.3 | Services orchestration |
| Certbot | latest | Let's Encrypt SSL (auto-renews) |
| UFW | system | Firewall |

---

## 🔑 Credentials & Configuration

### SSH Access

```
Host: 192.81.212.150
User: root
Droplet public key:
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtJzmKHrKBYJUpsQy/BzHSFqeB7AH9zNqfL/0MHl8vr root@droplet
```

### GitHub Repository

```
Repo:   git@github.com:Technest-Tech/barq-wadih.git
Branch: main
Path on server: /var/www/barq-wadih/
```

### MySQL (Docker)

```
Host:          127.0.0.1:3306
Database:      barq_wadih
User:          barq_user
Password:      ***REMOVED***
Root Password: ***REMOVED***
Container:     barq_mysql
```

### Redis (Docker)

```
Host:      127.0.0.1:6379
Password:  none
Container: barq_redis
```

### Meilisearch (Docker)

```
Host:       http://127.0.0.1:7700
Master Key: ***REMOVED***
Container:  barq_meilisearch
```

### Laravel Backend (.env at /var/www/barq-wadih/backend/.env)

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.barqwadih.com
APP_KEY=***REMOVED***
REDIS_CLIENT=phpredis
SANCTUM_STATEFUL_DOMAINS=barqwadih.com,www.barqwadih.com
DB_DATABASE=barq_wadih / DB_USERNAME=barq_user / DB_PASSWORD=***REMOVED***
```

### Next.js Frontend (.env.local at /var/www/barq-wadih/frontend/.env.local)

```
NEXT_PUBLIC_API_URL=https://api.barqwadih.com

# Firebase (Phone OTP — web)
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyC4o2_8_-nvq_mhB1fUDV25M8cFUY8IrVA
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=barqwadih-40271.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=barqwadih-40271
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=barqwadih-40271.firebasestorage.app
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=816087371543
NEXT_PUBLIC_FIREBASE_APP_ID=1:816087371543:web:ae264e2a5c776e1363f152
```

⚠️ These vars must be present in `/var/www/barq-wadih/frontend/.env.local` on the server or web phone OTP will not work.

---

## 📁 Key File Paths

| Purpose | Path |
|---------|------|
| Project root | `/var/www/barq-wadih/` |
| Backend | `/var/www/barq-wadih/backend/` |
| Frontend | `/var/www/barq-wadih/frontend/` |
| Backend .env | `/var/www/barq-wadih/backend/.env` |
| Frontend .env | `/var/www/barq-wadih/frontend/.env.local` |
| Nginx frontend | `/etc/nginx/sites-available/barqwadih-frontend` |
| Nginx API | `/etc/nginx/sites-available/barqwadih-api` |
| Supervisor workers | `/etc/supervisor/conf.d/barq-worker.conf` |
| Laravel logs | `/var/www/barq-wadih/backend/storage/logs/laravel.log` |
| Worker logs | `/var/www/barq-wadih/backend/storage/logs/worker.log` |
| SSL certs | `/etc/letsencrypt/live/barqwadih.com/` |

---

## 🔒 SSL Certificates

- Provider: Let's Encrypt (Certbot)
- Domains: barqwadih.com, www.barqwadih.com, api.barqwadih.com
- Auto-renewal: YES (certbot systemd timer)
- HTTP redirects to HTTPS automatically

---

## 🔥 Firewall Rules (UFW)

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (→ HTTPS redirect) |
| 443 | TCP | HTTPS |

---

## 📋 Key Deployment Decisions

### phpredis vs predis
The .env was set to `REDIS_CLIENT=predis` but predis isn't a composer dependency.
Switched to `REDIS_CLIENT=phpredis` (php8.3-redis system extension — faster, no composer dep needed).

### PHP system install (not Docker)
Laravel needs PHP-FPM for Nginx FastCGI integration. System PHP is simpler and faster for this use case.

### PM2 for Next.js
Provides process resurrection, startup-on-boot, and log management without extra Docker containers.

### Docker only for services
MySQL, Redis, Meilisearch run in Docker for isolation. App code stays on host for easy git-pull deployments.

### Firebase credentials removed from git
GitHub secret scanning blocked the push because `backend/storage/firebase-service-account.json` was committed.
The file was removed from git history using `git filter-branch`. It must be uploaded manually to the server.

### TypeScript build fixes applied
Three TypeScript errors fixed during deployment:
1. `img.url` → `img.image_url` in AdJsonLd component
2. Added `user_id` and optional `user` to `AdListItem` type
3. Added explicit `Variants` typing to Framer Motion animation objects in AuthModal

---

## 🚀 Re-deployment Runbook

### Redeploy backend after code change:
```bash
ssh root@192.81.212.150
cd /var/www/barq-wadih && git pull origin main
cd backend
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-req=ext-redis
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan view:cache
supervisorctl restart barq-worker:*
```

### Redeploy frontend after code change:
```bash
ssh root@192.81.212.150
cd /var/www/barq-wadih && git pull origin main
cd frontend
npm install --legacy-peer-deps
npm run build
pm2 restart barq-frontend
```

### Restart all services:
```bash
ssh root@192.81.212.150
pm2 restart barq-frontend
supervisorctl restart barq-worker:*
systemctl restart php8.3-fpm nginx
docker compose -f /var/www/barq-wadih/docker-compose.yml restart
```

---

## 📊 Monitoring Commands

```bash
# Frontend process
pm2 status && pm2 logs barq-frontend

# Queue workers
supervisorctl status
tail -f /var/www/barq-wadih/backend/storage/logs/worker.log

# Laravel app logs
tail -f /var/www/barq-wadih/backend/storage/logs/laravel.log

# Docker services
docker compose -f /var/www/barq-wadih/docker-compose.yml ps

# Nginx
systemctl status nginx

# SSL certs
certbot certificates

# Full health check
curl https://api.barqwadih.com/api/v1/health
```

---

## ✅ Deployment Status (2026-04-25)

| Check | Status |
|-------|--------|
| GitHub push | ✅ |
| Code on server | ✅ |
| MySQL | ✅ healthy |
| Redis | ✅ healthy |
| Meilisearch | ✅ running (unhealthy health check — Docker check config issue, app works) |
| PHP 8.3-FPM | ✅ running |
| 25 DB migrations | ✅ all ran |
| Next.js build | ✅ successful |
| PM2 barq-frontend | ✅ online |
| 2x Queue workers | ✅ running |
| Nginx | ✅ running |
| SSL (all 3 domains) | ✅ issued |
| HTTP→HTTPS redirect | ✅ active |
| UFW firewall | ✅ active |
| API health endpoint | ✅ `{"database":"ok","redis":"ok","meilisearch":"ok"}` |
| Frontend HTTP 200 | ✅ barqwadih.com returns 200 |

---

## 🔑 Firebase Android SHA Fingerprints

### What are these?
Firebase Phone Auth (OTP) on Android requires your app's signing certificate fingerprint to be registered in the Firebase console. Firebase uses it to verify the SMS request is coming from your real app — without it, `verifyPhoneNumber` silently fails and no OTP is sent.

There are **two separate keystores** — debug and release — and each needs its own fingerprint registered.

### Currently registered (debug keystore — for development only)
```
SHA-1:   A8:4E:5C:98:7F:BC:F9:DF:CB:0A:BA:E7:0D:5F:2B:FD:5B:47:EC:1F
SHA-256: F2:06:0E:76:9C:39:C3:40:4F:6E:F2:06:B5:E7:EB:F6:12:32:1E:C8:A3:24:0D:5A:AB:CE:F4:3D:DF:6D:FB:32
Keystore: ~/.android/debug.keystore (local machine — development only)
```

### ⚠️ REQUIRED: Authorize production domain for web OTP
Firebase blocks phone auth from unauthorized domains. Go to:
**Firebase Console → Authentication → Settings → Authorized domains**
and add:
```
barqwadih.com
www.barqwadih.com
```
`localhost` is pre-authorized for development. Without this, web OTP will throw `auth/unauthorized-domain`.

---

### ⚠️ REQUIRED BEFORE PRODUCTION RELEASE (Android)
The debug keystore fingerprints above **will not work** for a production/Play Store build. Production APKs are signed with a **release keystore** (or Google Play App Signing).

**Steps when releasing to production:**

1. Get the release SHA fingerprints:
   - If using **Google Play App Signing** (recommended): go to Play Console → Release → Setup → App Signing → copy the SHA-1 shown there
   - If using your own release keystore:
     ```bash
     keytool -list -v -keystore your-release.keystore -alias your-alias
     ```

2. Add them in **Firebase Console → Project Settings → barqwadih app → Add fingerprint**

3. Re-download `google-services.json` and replace `mobile/android/app/google-services.json`

4. Rebuild and release the app

**OTP will NOT work in production until this is done.**

---

## ⚠️ Pending Manual Steps

1. **Firebase Service Account** — Upload `firebase-service-account.json` manually:
   ```bash
   scp backend/storage/firebase-service-account.json root@192.81.212.150:/var/www/barq-wadih/backend/storage/
   ```
2. **DigitalOcean Spaces** — Add to `/var/www/barq-wadih/backend/.env`:
   ```
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   ```
   Then run `php artisan config:cache`
3. **Seed data** — Run `php artisan db:seed` for initial categories/regions
4. **Meilisearch index** — After seeding, run:
   ```bash
   php artisan scout:import "App\Models\Ad"
   ```
