# Rampur Library — Library Management System

A complete library management system:

| Part | Tech | Where it runs |
|---|---|---|
| **Member app** (`apps/mobile_app`) | Flutter | Android APK/AAB + iOS IPA, built by GitHub Actions |
| **Admin panel** (`apps/admin_panel`) | Flutter Web | Vercel |
| **Public website** (`site`) | Next.js (server-rendered, SEO) | Vercel |
| **Backend** (`firebase`, `functions`) | Firebase Auth, Firestore, Storage, Cloud Messaging, Cloud Functions | Google Cloud |
| **Shared code** (`packages/library_core`) | Dart package: models, repository, business rules | used by both Flutter apps |

👉 **First-time setup: [docs/SETUP.md](docs/SETUP.md)** (Firebase project, GitHub secrets, Vercel token).

## Features

### Member app (Android & iOS)
- **OTP login with mobile number** (Firebase Phone Auth, auto-read SMS on Android)
- Onboarding, profile completion, **editable profile** with photo, DOB, address, favourite genres
- **Digital membership card** with QR code (membership number auto-assigned: `RPL-000001`)
- Catalogue: home feed (featured, new arrivals, most reviewed, categories), **search** by title/author/ISBN, filters (available now, language), **ISBN barcode scanner**
- Book page: availability, shelf location, description, **ratings & reviews**, share, wishlist
- **Reservations / holds** with waiting-list queue position; copy is held automatically when it comes back
- **My Books**: current loans with due-date progress, **self-service renewal**, reservations, reading history, wishlist
- **Fines** overview, **book purchase suggestions**, **events & workshops**, feedback
- **Push notifications** (FCM): issue/return receipts, due-soon and overdue reminders, reservation ready, fines, renewals, library-wide announcements — plus an in-app **notification inbox**
- Settings: push on/off, light/dark theme, privacy/terms, **in-app account deletion** (App Store / Play requirement)
- Firebase Analytics, graceful "not configured" screen when built without secrets

### Admin panel (web)
- Staff sign-in (email/password) with **role-based access**: *admin* and *librarian* (Firebase custom claims)
- **Dashboard**: live counts, 14-day issue chart, overdue list, waiting list, fines collected
- **Issue / Return desk**: find member by membership number or phone (QR scanners type into the field), find book by ISBN or title, rule checks (limits, overdue, suspended, fines), custom loan period, return with automatic **fine calculation**, waive, extend, **mark lost** with replacement charge, send reminders
- **Books**: add/edit with **Google Books ISBN auto-fill**, cover upload, copies & shelf, categories, featured, e-book link; **bulk CSV import** + template; delete with safety checks
- **Categories**, **Members** (search, walk-in registration, profile, loans, fines, reservations, suspend/reactivate, membership type/expiry/limits, direct push message, manual charges)
- **Reservations** (ready-for-pickup shelf, waiting list, issue from hold), **Fines** (collect cash/UPI/card, waive)
- **Push notifications** composer with templates, preview and history
- **Events** (banner image, publish, auto-announce), **Book suggestions** workflow (approve/acquired/reject → member is notified)
- **Reports**: CSV exports (catalogue, 12-month circulation, most borrowed, members, fines ledger) and an **activity/audit log**
- **Staff** management and **Settings** (loan period, renewals, fines, grace days, caps, hold days, reminder days, contact info, app links)

### Public website (SEO)
- Server-rendered with Incremental Static Regeneration — fast and fully indexable
- Pages for every book and category, catalogue search, events, visit/membership rules, app download, privacy & terms
- `sitemap.xml`, `robots.txt`, canonical URLs, Open Graph/Twitter cards, web manifest
- schema.org JSON-LD: `Library` (+ sitelinks search box), `Book` with availability and ratings, `BreadcrumbList`, `Event`

### Backend automation (Cloud Functions)
- Membership numbers, welcome message, push delivery with stale-token cleanup
- Reservation queue: holds a copy for the next member on return, expires uncollected holds
- Daily job (9 AM IST): due-soon reminders, mark overdue, accrue fines, overdue reminders
- Server-validated renewals, rating aggregation, category counts, fine totals per member
- Staff role management, account deletion, broadcasts to the `all` topic, event announcements
- Firestore & Storage **security rules** and composite indexes

## CI/CD (GitHub Actions)

| Workflow | Trigger | What it does |
|---|---|---|
| `ci.yml` | every push / PR | `flutter analyze` + tests, functions build + tests, website build |
| `deploy-web.yml` | push to `main` | builds the admin panel and website and deploys both to **Vercel** |
| `firebase.yml` | push to `main` (backend changes) | deploys rules, indexes and Cloud Functions |
| `mobile.yml` | push to `main`, tags `v*` | builds **APK**, split APKs, **AAB** and **IPA**; tags publish a GitHub Release |

In **demo mode** (no Firebase keys) the app uses OTP `123456` and the admin panel `admin@demo.com` / `demo1234`, both on sample data.

Download the latest app builds from **Actions → Mobile builds → Artifacts**, or from **Releases** for tagged versions.

## Local development

```bash
# Flutter apps (pass your Firebase config)
cd apps/mobile_app && flutter create --platforms=android,ios --org com.rampurlibrary --project-name rampur_library . \
  && python3 ../../scripts/prepare_mobile.py . && flutter run --dart-define-from-file=dart_defines.json
cd apps/admin_panel && flutter run -d chrome --dart-define-from-file=dart_defines.json

# Website
cd site && cp .env.example .env.local && npm install && npm run dev

# Functions
cd functions && npm install && npm run build && npm test
```

`dart_defines.json` holds the public Firebase config — generate it with `scripts/write_dart_defines.py` (see SETUP).

## Repository layout

```
apps/mobile_app      Flutter member app (lib/, assets/, ios/Podfile)
apps/admin_panel     Flutter web admin panel (lib/, web/ with vercel.json)
packages/library_core Shared models, repository, utils (+ unit tests)
site/                Next.js public website
functions/           Cloud Functions (TypeScript)
firebase/            Firestore/Storage rules and indexes
scripts/             CI helpers (native project config, dart defines)
tools/               set-admin.mjs (bootstrap first admin), seed.mjs (sample data)
```
