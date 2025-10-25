# Arduino UNO + SIM900 + NEO-6M GPS → Firebase (UPS Tracker)

This guide shows how to wire SIM900 and NEO-6M to Arduino UNO and push GPS updates to your deployed Cloud Function `ingestGps`.

## Components
- Arduino UNO
- SIM900 GSM module with antenna + micro SIM (data plan enabled)
- Ublox NEO-6M GPS module
- 5V 2A power supply (barrel jack recommended)
- 1000–2200µF electrolytic capacitor across 5V–GND (recommended)
- Jumper wires

## Wiring
- Power: Barrel jack → Arduino; SIM900 VCC → 5V; NEO-6M VCC → 5V; All GNDs common
- Signals:
  - SIM900 TX → D9 (Arduino RX for GSM)
  - SIM900 RX → D8 (Arduino TX for GSM)
  - NEO-6M TX → D4 (Arduino RX for GPS)

Note: USB power is not enough for SIM900 bursts; use a stable 5V 2A supply.

## Cloud Function URL
- Region is `asia-south1` in this project; function path is `/ingestGps`.
- Example host: `asia-south1-<project-id>.cloudfunctions.net`

## Firestore Setup
- Create one doc in `tracker_devices`:
  - Fields: `apiKey: string`, `enabled: true`, optional `secret: string` for HMAC
- Create one doc in `vehicles/{vehicleId}` with `name`, `lat`, `lng`, `active` (true)

## Arduino Sketch (SIM900 HTTP POST)

Use your provided sketch and set:
- `APN` to your carrier (e.g., `dialogbb` or `mobitel`)
- `SERVER` to `asia-south1-<project-id>.cloudfunctions.net`
- `ENDPOINT` to `/ingestGps`
- `API_KEY` to `tracker_devices.apiKey`
- `VEHICLE_ID` to your Firestore vehicle doc id

Tips:
- If you use HMAC, compute base64 HMAC-SHA256 over the raw JSON and send `X-Signature` header.
- Send every 15–30 seconds to balance cost and freshness.

## Testing
1. Power on; wait for SIM900 NET LED to slow blink (registered).
2. Open Serial Monitor @ 9600 baud; verify GPRS ready.
3. Watch for `Sent to Firebase!` and check Firestore `vehicles/{vehicleId}` for updates.
4. Open the app; the marker should move in real-time.

## Troubleshooting
- GPS fix: Move outdoors, ensure antenna placement.
- APN errors: Verify operator APN and data plan.
- Power resets: Use ≥2A adapter + capacitor.
- Signature failed: Ensure `secret` matches and base64 HMAC is correct.

## Optional Improvements
- Buffer and batch when no network; retry with backoff.
- Add speed/heading/accuracy and show in app tooltip.
- Reduce payload size and send only when change > 10m to save costs.
