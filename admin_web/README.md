# UPS Admin Web

Security hardening has been added:

- Admin role enforcement using Firebase Auth custom claims (with Firestore `roles/{uid}` fallback)
- Route guards redirect non-admin users to an unauthorized screen
- Inactivity auto-lock after 15 minutes; requires password re-auth or sign-out
- Admin action audit logging to Firestore collection `admin_audit_logs`
- Content-Security-Policy in `web/index.html` to mitigate XSS

How to grant admin access (run in trusted backend context or Firebase Admin SDK):

```js
// Node.js Admin SDK example
const admin = require('firebase-admin');
await admin.auth().setCustomUserClaims(uid, { admin: true });
```

Alternatively, you can create a Firestore document `roles/{uid}` with `{ admin: true }`.

Notes:
- Ensure your Firestore Security Rules allow reads/writes that your admin UI performs, and restrict `admin_audit_logs` writes to authenticated users.
- If you change allowed origins (APIs, fonts, etc.), update the CSP in `web/index.html` accordingly.
