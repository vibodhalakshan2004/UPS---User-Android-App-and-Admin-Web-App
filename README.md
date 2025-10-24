# UPS Apps (Flutter + Firebase)

Clean, production-focused repo with two apps:

- User app (Flutter): `lib/`, `android/`, `web/`, shared `assets/`
- Admin web app (Flutter): `admin_web/`

Both apps use OpenStreetMap via flutter_map and Firebase (Auth, Firestore, Storage, Functions).

## Quick start

Prereqs: Flutter 3.x, Firebase project set up (FlutterFire already configured in this repo).

Run the user app (mobile or web):

```sh
flutter pub get
flutter run        # pick your device
```

Run the admin web app (Chrome):

```sh
cd admin_web
flutter pub get
flutter run -d chrome

Admin login is restricted to admin accounts.

Grant admin:
1) Create the user in Firebase Authentication (email/password)
2) Create Firestore doc `roles/{UID}` with `{ admin: true }` where UID is the Authentication UID

That’s it. Vehicles, bookings, complaints, news, and users are all wired to Firestore with secure rules.

## Project layout

- `lib/`            User app code
- `admin_web/`      Admin Flutter web app
- `assets/`         Shared images (e.g., app logo)
- `android/`        Android project for user app
- `web/`            Flutter web support for user app
- `firestore.rules` Firestore security rules
- `functions/`      Cloud Functions (GPS ingest endpoint)

Non-essential docs and samples have been removed for clarity.
flutter run

# Run admin panel
cd admin_web
flutter run -d chrome
