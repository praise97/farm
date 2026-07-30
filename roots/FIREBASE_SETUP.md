# Roots — Firebase & Database Setup (Step by Step)

This guide connects **Roots** to Firebase so Android, iOS, Windows, macOS, Linux, and Web share the same Auth + Firestore data. Until you finish these steps, the app runs in **offline/demo mode** with local Hive storage.

Demo login: `farmer@roots.app` / `roots123`

---

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** → name it `roots-farm` (or similar).
3. Disable Google Analytics if you prefer (optional).
4. Create the project.

---

## 2. Enable the products Roots uses

In the Firebase project:

### Authentication
1. **Build → Authentication → Get started**
2. Enable:
   - **Email/Password**
   - **Google**
   - (Optional) **Phone**

### Cloud Firestore
1. **Build → Firestore Database → Create database**
2. Start in **production mode** (we’ll add rules next) or **test mode** for local dev only.
3. Choose a region close to your users (e.g. `europe-west` or nearest).

### Storage
1. **Build → Storage → Get started**
2. Use default security rules for now; tighten later.

### Cloud Messaging (FCM)
1. **Build → Messaging**
2. No extra setup for Android beyond `google-services.json`.
3. For iOS, upload an APNs key in Project Settings → Cloud Messaging.

---

## 3. Register each app platform

In **Project settings → Your apps**, add:

| Platform | Package / Bundle ID |
|----------|---------------------|
| Android  | `com.roots.roots` |
| iOS      | `com.roots.roots` |
| Web      | any nickname, e.g. `roots-web` |
| Windows  | FlutterFire will register |
| macOS    | `com.roots.roots` |

Download:
- Android: `google-services.json` → place in `android/app/`
- iOS: `GoogleService-Info.plist` → place in `ios/Runner/`

---

## 4. Configure FlutterFire (recommended)

```bash
cd roots
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
```

This regenerates `lib/firebase_options.dart` with real keys for all platforms.

Then open `lib/core/constants/app_constants.dart` and set:

```dart
static const firebaseConfigured = true;
```

---

## 5. Firestore data model (collections)

```
users/{userId}
  id, name, email, phone, farmId, role (owner|manager|worker), photoUrl, createdAt

farms/{farmId}
  id, name, ownerId, location, createdAt

farms/{farmId}/animals/{animalId}
  tagNumber, qrCode, breed, category, gender, birthDate, weight,
  colour, photoUrl, currentOwner, location, status, createdAt, updatedAt

farms/{farmId}/timeline/{eventId}
  animalId, type, title, notes, date, meta, cost

farms/{farmId}/equipment/{equipmentId}
  name, category, purchaseDate, purchasePrice, supplier, condition,
  currentLocation, photoUrl, serialNumber, warrantyUntil,
  serviceIntervalDays, lastServiceDate, nextServiceDate

farms/{farmId}/inventory/{itemId}
  name, category, quantity, unit, supplier, purchaseDate, expiryDate,
  minimumStock, costPrice, sellingPrice, barcode, storageLocation

farms/{farmId}/finance/{entryId}
  type (income|expense), category, description, amount, date, relatedId

farms/{farmId}/tasks/{taskId}
  title, description, assigneeId, assigneeName, dueDate, priority, status, sourceModule

farms/{farmId}/crops/{cropId}
  name, cropType, growthPercent, soilMoisture, statusNote, plantedAt, expectedHarvest

farms/{farmId}/alerts/{alertId}
  type, title, message, createdAt, read, relatedId

farms/{farmId}/mapPoints/{pointId}
  name, type, latitude, longitude, notes

farms/{farmId}/workers  (optional mirror of users under the farm)
```

### Animal `status` values
`alive`, `sold`, `dead`, `missing`, `pregnant`, `sick`, `quarantined`

### Roles & permissions
| Action | Owner | Manager | Worker |
|--------|-------|---------|--------|
| Invite workers | ✅ | ❌ | ❌ |
| Finance view/edit | ✅ | ✅ | ❌ |
| Delete records | ✅ | ✅ | ❌ |
| Add animals / stock adjust | ✅ | ✅ | ✅ |
| Add equipment | ✅ | ✅ | ❌ |
| Assign tasks | ✅ | ✅ | ❌ |

---

## 6. Security rules (starter)

Paste into Firestore Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }
    function userDoc() { return get(/databases/$(database)/documents/users/$(request.auth.uid)).data; }
    function sameFarm(farmId) { return signedIn() && userDoc().farmId == farmId; }
    function isManager(farmId) {
      return sameFarm(farmId) && userDoc().role in ['owner', 'manager'];
    }

    match /users/{userId} {
      allow read: if signedIn();
      allow write: if signedIn() && request.auth.uid == userId;
    }

    match /farms/{farmId} {
      allow read: if sameFarm(farmId);
      allow write: if isManager(farmId);

      match /{collection}/{docId} {
        allow read: if sameFarm(farmId);
        allow write: if sameFarm(farmId);
      }
    }
  }
}
```

Tighten finance writes to managers only when you go live.

Storage rules (photos):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /farms/{farmId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

## 7. Indexes

When Firestore asks for an index (e.g. animals by `status` + `tagNumber`), click the link in the error and create it. Common ones:

- `animals`: `farmId` ASC, `tagNumber` ASC  
- `alerts`: `farmId` ASC, `createdAt` DESC  
- `tasks`: `farmId` ASC, `dueDate` ASC  

---

## 8. Google Sign-in extras

**Android:** add SHA-1 in Firebase Project Settings → Your Android app:

```bash
cd android
./gradlew signingReport
```

**iOS:** add reversed client ID URL scheme from `GoogleService-Info.plist` in Xcode.

**Web:** add authorized domains in Authentication → Settings.

---

## 9. Offline-first behaviour

Roots already:

1. Writes to **Hive** first (local).
2. Queues ops in `sync_queue`.
3. When `firebaseConfigured == true` and the device is online, `SyncService` pushes to Firestore.

After enabling Firebase, call sync on app resume / connectivity change (hook is ready in `lib/core/offline/sync_service.dart`).

---

## 10. Verify

1. `flutter run -d chrome` or Windows/Android.
2. Register a new owner → confirm `users` + `farms` docs appear in Firestore.
3. Add an animal offline → reconnect → confirm it syncs.
4. Log in on a second device with the same account → data loads.

---

## Partner note (Crop module)

The HTML crop dashboard from the original GitHub repo lives under `/farm`. In Roots, **Crops** is implemented as a compatible module with the same stats/growth UI so your partner can deepen crop features without blocking livestock & equipment work.
