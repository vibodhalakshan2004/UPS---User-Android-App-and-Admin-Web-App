# UPS Apps (Flutter + Firebase)

Monorepo housing three Flutter applications that share Firebase backends and assets.

## Apps

- **Desktop Admin** – `apps/admin_desktop`
- **Mobile User** – `apps/user_mobile`
- **Web Admin** – `apps/admin_web`

Cloud Functions (telemetry ingest, webhooks, etc.) live in `functions/`. Documentation is under `docs/`.

## Quick start

All apps target Flutter 3.19+ with Firebase already configured through FlutterFire.

### Desktop admin (Windows)

```powershell
cd apps/admin_desktop
flutter pub get
flutter run -d windows
```

### Mobile user app (Android)

```powershell
cd apps/user_mobile
flutter pub get
flutter run        # select connected device or emulator
```

### Web admin panel (Chrome)

```powershell
cd apps/admin_web
flutter pub get
flutter run -d chrome
```

## Firebase roles reminder

Admin surfaces are restricted. To grant access:

1. Create the user in Firebase Authentication (email/password).
2. Add a Firestore document `roles/{UID}` with `{ admin: true }`.

Bookings, complaints, news, tracking, and dashboards are wired to Firestore with matching security rules.
