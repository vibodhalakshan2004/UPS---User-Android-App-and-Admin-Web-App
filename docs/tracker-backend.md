# GPS Tracker Backend: Architecture and Contract

This document defines the backend module you need to accept real-time GPS updates from your garbage trucks and feed both the Admin Web and User apps via Firestore.

Goal:
- Each truck device (hardware tracker or phone app) periodically sends location updates.
- Backend authenticates and validates the data, then writes to Firestore:
  - `vehicles/{vehicleId}` for the current location (used by maps)
  - `vehicles/{vehicleId}/positions/{timestamp}` for historical tracking (optional)

## High-level architecture

- Ingestion API: HTTPS endpoint (Cloud Functions/Cloud Run) that receives JSON payloads from trackers.
- Auth: one of
  1) Per-device API keys with HMAC signature
  2) Firebase Auth (custom tokens) from a driver mobile app
  3) mTLS or IP allowlist for hardware trackers (if supported)
- Validation: schema, rate limits, and reasonable bounds for lat/lng/accuracy.
- Storage: Firestore (current doc + optional history subcollection). Optionally, Cloud Storage/BigQuery for long-term analytics.
- Realtime delivery: Apps already subscribe to Firestore (`vehicles` collection) and will update instantly.

## Data model

Collection: `vehicles`
- Doc ID: vehicleId (stable ID for truck, e.g., license plate or tracker serial)
- Fields:
  - `name`: string (display)
  - `lat`: number (latest latitude)
  - `lng`: number (latest longitude)
  - `active`: bool (controls visibility)
  - `updatedAt`: server timestamp (last update time)
  - Optional telemetry: `speedKph`, `heading`, `accuracyM`, `batteryPct`

Subcollection (optional): `vehicles/{vehicleId}/positions`
- Doc ID: `{epochMillis}` or auto-ID
- Fields:
  - `lat`, `lng`, `at`: timestamp
  - Optional: `speedKph`, `heading`, `accuracyM`

## Ingestion API contract

Endpoint: `POST /ingest/gps`

Headers:
- `X-Tracker-Key`: string (device API key)
- `X-Signature`: string (HMAC-SHA256 of body using device secret; base64) [optional but recommended]
- `Content-Type: application/json`

Body (JSON):
```
{
  "vehicleId": "TRUCK_001",
  "lat": 7.450812,
  "lng": 80.032145,
  "speedKph": 22.5,        // optional
  "heading": 135,          // optional
  "accuracyM": 5,          // optional
  "batteryPct": 88,        // optional
  "sentAt": 1739041234567  // epoch ms from device clock (optional)
}
```

Response:
- 200 OK `{ "status": "ok" }`
- 400/401/429 with `{ "error": "..." }` on validation/auth/rate-limit errors

Validation rules:
- `vehicleId` present, known, and provisioned.
- `lat` in [-90, 90], `lng` in [-180, 180].
- rate ≤ 1 update per 2–5 seconds per device (configurable). Extra events can be accepted but deduplicated or sampled.

## Auth and provisioning

Devices table/collection: `tracker_devices/{deviceId}`
- Fields:
  - `vehicleId`: string (link to vehicle)
  - `apiKey`: string (public key)
  - `secret`: string (server-only secret for HMAC)
  - `enabled`: bool

Ingestion flow:
1) Lookup `tracker_devices` by `apiKey` (or `deviceId`).
2) Verify `enabled == true`.
3) Verify `X-Signature` matches `HMAC_SHA256(secret, body)` if using signatures.
4) Use linked `vehicleId` to write Firestore updates.

Alternative (Firebase Auth):
- Driver mobile app signs in; backend trusts `request.auth.uid` → maps to `vehicleId` using a server-side registry.

## Firestore writes

On each valid update:
1) Update current doc:
```
vehicles/{vehicleId} = {
  lat: <lat>,
  lng: <lng>,
  updatedAt: FieldValue.serverTimestamp(),
  speedKph?: <num>,
  heading?: <num>,
  accuracyM?: <num>,
  batteryPct?: <num>,
}
```
2) Optional history:
```
vehicles/{vehicleId}/positions/{epochMillis} = {
  lat: <lat>,
  lng: <lng>,
  at: Timestamp.fromMillis(epochMillis),
  speedKph?, heading?, accuracyM?
}
```

The apps already subscribe to `vehicles` and will update in real time.

## Cloud Functions example (Node.js)

```js
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
admin.initializeApp();
const db = admin.firestore();

function isValidLatLng(lat, lng) {
  return typeof lat === 'number' && typeof lng === 'number' &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

exports.ingestGps = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  const apiKey = req.header('X-Tracker-Key');
  const signature = req.header('X-Signature');
  const body = req.body || {};
  try {
    if (!apiKey) return res.status(401).json({ error: 'Missing key' });
    const devSnap = await db.collection('tracker_devices').where('apiKey', '==', apiKey).limit(1).get();
    if (devSnap.empty) return res.status(401).json({ error: 'Unknown key' });
    const dev = devSnap.docs[0].data();
    if (dev.enabled !== true) return res.status(403).json({ error: 'Device disabled' });

    // Optional HMAC verification
    if (dev.secret && signature) {
      const h = crypto.createHmac('sha256', dev.secret);
      const raw = typeof req.rawBody === 'string' ? req.rawBody : JSON.stringify(body);
      h.update(raw);
      const expected = h.digest('base64');
      if (expected !== signature) return res.status(401).json({ error: 'Bad signature' });
    }

    const { vehicleId, lat, lng, speedKph, heading, accuracyM, batteryPct, sentAt } = body;
    if (!vehicleId || !isValidLatLng(lat, lng)) return res.status(400).json({ error: 'Bad payload' });

    const now = Date.now();
    const histId = (sentAt && Number.isFinite(sentAt)) ? String(sentAt) : String(now);

    const vehicleRef = db.collection('vehicles').doc(vehicleId);
    const positionRef = vehicleRef.collection('positions').doc(histId);

    const current = {
      lat, lng,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(speedKph != null ? { speedKph } : {}),
      ...(heading != null ? { heading } : {}),
      ...(accuracyM != null ? { accuracyM } : {}),
      ...(batteryPct != null ? { batteryPct } : {}),
    };

    await db.runTransaction(async tx => {
      tx.set(vehicleRef, current, { merge: true });
      tx.set(positionRef, {
        lat, lng,
        at: admin.firestore.Timestamp.fromMillis(Number(histId)),
        ...(speedKph != null ? { speedKph } : {}),
        ...(heading != null ? { heading } : {}),
        ...(accuracyM != null ? { accuracyM } : {}),
      });
    });

    return res.json({ status: 'ok' });
  } catch (e) {
    console.error('ingestGps error', e);
    return res.status(500).json({ error: 'Internal error' });
  }
});
```

Deployment (CLI):
- `firebase init functions` → Node.js
- Add endpoint above, then `firebase deploy --only functions:ingestGps`

## Security rules alignment

The existing `firestore.rules` already allow public reads and admin writes to `vehicles`. For server-side ingestion, you have two options:
1) Use Admin SDK (bypasses rules) in Cloud Functions/Run (recommended).
2) If writing from the client (not recommended), you must permit writes for that client identity.

## Rate limiting & sampling

- Trackers can send every 2–5 seconds while moving; back off to 15–60 seconds when stopped.
- Server can optionally drop duplicate locations or sample to reduce write costs.

## Retention & costs

- Current doc: keep indefinitely (small).
- History: set TTL/cleanup (e.g., keep 7–30 days), or export to BigQuery for long-term analytics.

## Monitoring & observability

- Log every ingest outcome (success/error) with device ID and latency.
- Add a health check endpoint for trackers to test connectivity.
- Add an admin dashboard widget that shows last update time per vehicle and highlights stale trackers (e.g., >5 minutes).

## Stale tracker detection (UI idea)

- In Admin, show `updatedAt` next to each vehicle and color markers red if stale.
- A Cloud Function can periodically scan for stale devices and notify ops if a tracker is down.

## Device provisioning workflow

1) Create a `vehicles/{vehicleId}` doc with `name`, `active: true`.
2) Create a `tracker_devices/{deviceId}` with `apiKey`, `secret`, `enabled: true`, and `vehicleId`.
3) Configure the tracker firmware/app with the endpoint and credentials.
4) Verify data flow in Admin → Tracker.

---

This contract is ready to hand to another assistant or developer to implement the Cloud Function/Run service in your preferred stack.
