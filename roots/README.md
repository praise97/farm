# Roots

Farm management for **livestock**, **equipment**, **inventory**, **finance**, **tasks**, and **crops** — one Flutter codebase for:

- Android · iOS · Windows · macOS · Linux · Web

Built with **Flutter**, **Riverpod**, **Material 3**, **Hive (offline-first)**, and **Firebase** (Auth, Firestore, Storage, FCM).

The previous HTML crop prototype remains in the sibling `farm/` folder for your crop partner.

## Quick start

```bash
cd roots
flutter pub get
flutter run -d windows   # or chrome, android, etc.
```

**Demo login:** `farmer@roots.app` / `roots123`

Roles seeded: Owner (John Farmer), Manager (Tendai Moyo), Worker (Chipo Ncube).

## What’s included

| Module | Status |
|--------|--------|
| Auth (login / register / forgot / Google placeholder) | ✅ Demo + Firebase-ready |
| Roles (Owner / Manager / Worker) + permissions | ✅ |
| Dashboard (desktop sidebar + mobile nav, Imali-style cards) | ✅ |
| Livestock (tags, QR, timeline, vaccines, weight graphs, health) | ✅ Primary focus |
| Equipment (categories, condition, service reminders) | ✅ Primary focus |
| Inventory (low stock / expiry alerts, stock in/out) | ✅ |
| Finance (income/expense, charts, role-gated) | ✅ |
| Crops (ported from FarmSmartPro dashboard for partner) | ✅ Stub + UI |
| Tasks, Alerts, Map points, Reports, Search, Workers | ✅ |
| Light / dark mode | ✅ |
| Offline Hive store + sync queue | ✅ |

## Architecture

```
lib/
  core/           theme, router, offline store, permissions, sync
  domain/         entities
  data/           repository + demo seed
  presentation/   Riverpod providers, screens, shell, widgets
```

## Firebase

Follow **[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** step by step, then set:

```dart
// lib/core/constants/app_constants.dart
static const firebaseConfigured = true;
```

## Design

UI follows your screenshots:

- Dark navy sidebar (`#0E1F2E`) + green accents on desktop  
- Gradient hero banners and rounded action cards (Imali-style) on mobile  
- Material 3 + Plus Jakarta Sans  

## Scripts

```bash
flutter run -d chrome
flutter run -d windows
flutter build apk
flutter build windows
flutter build web
```
