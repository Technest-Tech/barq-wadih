# برق واضح — Barq Wadih

> **"مجتمع تجاري موثوق"** — Trusted Commercial Community

A classifieds & marketplace platform for Saudi Arabia (KSA), built on ethical trade principles with honor-based commissions and community accountability.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Laravel 11+ (PHP 8.3) — RESTful JSON API |
| **Frontend** | Next.js 14+ (TypeScript, App Router, Vanilla CSS) |
| **Mobile** | Flutter 3.x (Dart) — iOS & Android |
| **Database** | MySQL 8 (`utf8mb4_unicode_ci`) |
| **Search** | Meilisearch (self-hosted) + Laravel Scout |
| **Cache & Queue** | Redis 7.x |
| **Auth** | Laravel Sanctum + Firebase Auth (Phone OTP) |
| **Chat** | Firebase Firestore (real-time) |
| **Storage** | DigitalOcean Spaces (S3-compatible) |
| **Infrastructure** | DigitalOcean Droplet (16GB RAM) |
| **CI/CD** | GitHub Actions |

---

## 📁 Monorepo Structure

```
barq-wadih-tech/
├── backend/          # Laravel 11 API
├── frontend/         # Next.js 14+ (Web + Admin Panel)
├── mobile/           # Flutter 3.x (iOS + Android)
├── docs/             # Project documentation
├── infra/            # Infrastructure & deployment scripts
├── scripts/          # Dev convenience scripts
├── sprints/          # Sprint planning docs
├── docker-compose.yml
├── Makefile
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| PHP | 8.3+ |
| Composer | 2.x |
| Node.js | 20 LTS |
| Flutter | 3.x |
| Docker Desktop | Latest |
| Git | Latest |

### 1. Clone the Repository

```bash
git clone git@github.com:<your-org>/barq-wadih-tech.git
cd barq-wadih-tech
```

### 2. Start Local Services (Docker)

```bash
docker compose up -d
# Starts: MySQL 8 (3306), Redis (6379), Meilisearch (7700)
```

### 3. Backend (Laravel)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
# API available at http://localhost:8000
```

### 4. Frontend (Next.js)

```bash
cd frontend
npm install
cp .env.local.example .env.local
npm run dev
# Web app available at http://localhost:3000
```

### 5. Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

### 6. Verify

```bash
# Health check
curl http://localhost:8000/api/v1/health
# Expected: { "success": true, "data": { "status": "ok" } }
```

---

## 🌐 Internationalization

- **Primary Language**: Arabic (ar) — RTL
- **Secondary Language**: English (en) — LTR
- **Arabic Font**: IBM Plex Sans Arabic
- **English Font**: Inter

---

## 📋 Sprint Roadmap

| Sprint | Focus | Phase |
|---|---|---|
| 1 | Project Scaffolding & Dev Environment | Foundation |
| 2 | Database Schema & Models | Foundation |
| 3 | Authentication & User Profiles | Foundation |
| 4–6 | Core Features (Ads, Search, Chat) | Core |
| 7–10 | Advanced Features (Payments, Admin) | Advanced |
| 11–15 | Polish & Performance | Refinement |
| 16–20 | Deployment & Launch | Launch |

Full sprint details in [`sprints/`](./sprints/).

---

## 📄 Documentation

- [Project Overview](./docs/PROJECT_OVERVIEW.md)
- [Database Schema](./docs/DATABASE_SCHEMA.md)
- [Sprint List](./docs/SPRINT_LIST.md)

---

## 📜 License

Proprietary — All rights reserved.
