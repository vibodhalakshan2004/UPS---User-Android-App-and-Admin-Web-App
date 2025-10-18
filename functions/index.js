const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const crypto = require('crypto');

// Deploy close to Sri Lanka and cap resources for cost/perf
setGlobalOptions({ region: 'asia-south1', memoryMiB: 256, timeoutSeconds: 30 });

admin.initializeApp();
const db = admin.firestore();

function isValidLatLng(lat, lng) {
  return typeof lat === 'number' && typeof lng === 'number' &&
         lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

exports.ingestGps = onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  // Basic body size guard (e.g., < 2KB)
  try {
    const lenHeader = req.get('content-length');
    const raw = req.rawBody || Buffer.from('');
    const size = lenHeader ? parseInt(lenHeader, 10) : raw.length;
    if (Number.isFinite(size) && size > 2048) {
      return res.status(413).json({ error: 'Payload too large' });
    }
  } catch (_) {
    // ignore size parsing errors
  }

  const apiKey = req.header('X-Tracker-Key');
  const signature = req.header('X-Signature');
  const body = req.body || {};

  try {
    // Step 1: Authentication
    if (!apiKey) return res.status(401).json({ error: 'Missing API key' });

    const devSnap = await db.collection('tracker_devices')
      .where('apiKey', '==', apiKey).limit(1).get();

    if (devSnap.empty) return res.status(401).json({ error: 'Unknown key' });

    const dev = devSnap.docs[0].data();
    if (!dev.enabled) return res.status(403).json({ error: 'Device disabled' });

    // Optional HMAC signature check
    if (dev.secret && signature) {
      const hmac = crypto.createHmac('sha256', dev.secret);
      const raw = typeof req.rawBody === 'string' ? req.rawBody : JSON.stringify(body);
      hmac.update(raw);
      const expected = hmac.digest('base64');
      if (expected !== signature) return res.status(401).json({ error: 'Invalid signature' });
    }

    // Step 2: Validate Payload
    const { vehicleId, lat, lng, speedKph, heading, accuracyM, batteryPct, sentAt } = body;
    if (!vehicleId || !isValidLatLng(lat, lng))
      return res.status(400).json({ error: 'Bad payload' });

    const now = Date.now();
    const histId = sentAt && Number.isFinite(sentAt) ? String(sentAt) : String(now);

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

    // Step 3: Transaction (update + history)
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
