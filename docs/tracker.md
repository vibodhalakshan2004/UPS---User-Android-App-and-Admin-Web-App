# Waste Tracking with OpenStreetMap

This project uses OpenStreetMap via `flutter_map` to show live waste trucks and community bins on both the user app and the admin web app.

## Data model (Cloud Firestore)

Create and update the following collections to drive the maps:

- Collection `vehicles` (waste trucks)
  - Fields:
    - `name`: string, display name (e.g., "Truck 12")
    - `lat`: number, latitude
    - `lng`: number, longitude
    - `active`: bool, whether to show on map

- Collection `bins`
  - Fields:
    - `name`: string, display label
    - `lat`: number
    - `lng`: number

If the collections are empty, the apps show demo markers so the map isn't blank.

## Code locations

- User app screen: `lib/features/tracker/tracker_screen.dart`
- Admin web screen: `admin_web/lib/main.dart` -> `AdminTrackerScreen`

## Updating locations

To update a truck location from a backend/cron/driver app, write the new lat/lng to the corresponding `vehicles/<id>` document, and set `active: true` while the vehicle is in service.

Example document:

```json
{
  "name": "Truck 7",
  "lat": 5.6201,
  "lng": -0.1953,
  "active": true
}
```

## Map tiles and attribution

- Tiles: `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`
- Be sure to keep OpenStreetMap attribution visible.
- Consider setting a custom `userAgentPackageName` in the `TileLayer`.
