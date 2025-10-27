# UPS Apps (Flutter + Firebase)

Monorepo housing three Flutter applications that share Firebase backends and assets.

## Apps

- **Desktop Admin** – `apps/admin_desktop`
- **Mobile User** – `apps/user_mobile`
- **Web Admin** – `apps/admin_web`

Cloud Functions (telemetry ingest, webhooks, etc.) live in `functions/`. Documentation is under `docs/`.

## Quick start

All apps target Flutter 3.19+ with Firebase already configured through FlutterFire.

### Firebase configuration (all apps)

1. Copy each `firebase.env.example` file to `firebase.env` inside the matching app directory and populate it with fresh values from the Firebase console. The repo ignores the `.env` files so secrets stay local.
2. When running or building, pass the values via `--dart-define-from-file` (Flutter 3.16+):

	```powershell
	flutter run --dart-define-from-file=firebase.env
	flutter build apk --dart-define-from-file=firebase.env
	```

	For older toolchains, expand the file to multiple `--dart-define` flags.
3. **Rotate leaked keys** – the previous API keys were committed and must be regenerated in the Firebase console. After rotation, purge the old keys from Firebase usage and consider rewriting repository history (for example with `git filter-repo`) before pushing.

### Desktop admin (Windows)

```powershell
cd apps/admin_desktop
flutter pub get
flutter run -d windows --dart-define-from-file=firebase.env
```

### Mobile user app (Android)

```powershell
cd apps/user_mobile
flutter pub get
flutter run --dart-define-from-file=firebase.env   # select connected device or emulator
```

### Web admin panel (Chrome)

```powershell
cd apps/admin_web
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase.env
```

## Firebase roles reminder

Admin surfaces are restricted. To grant access:

1. Create the user in Firebase Authentication (email/password).
2. Add a Firestore document `roles/{UID}` with `{ admin: true }`.

Bookings, complaints, news, tracking, and dashboards are wired to Firestore with matching security rules.
