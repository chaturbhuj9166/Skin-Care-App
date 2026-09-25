// Firebase Cloud Messaging service.
//
// When Firebase is configured (see services/firebase.js) pushes are really
// sent through the Admin SDK to the DeviceToken rows registered by the app
// (POST /api/users/device-token, POST /api/doctors/device-token). Tokens the
// FCM API reports as unregistered/invalid are pruned as we go.
//
// When Firebase is NOT configured the module keeps its original console-log
// stub behaviour, so local dev without credentials works exactly as before
// and no call site needs to change.
const prisma = require('../config/db');
const firebase = require('../services/firebase');

const isConfigured = firebase.isConfigured;

// Topics used by the admin broadcast flow. Real FCM topics need the client to
// subscribe; instead we fan out to every registered token of that audience,
// which works with the tokens we already store.
const TOPIC_AUDIENCES = {
  'all-users': 'USER',
  'all-doctors': 'DOCTOR',
  'all-admins': 'ADMIN',
};

// FCM data payloads must be flat string->string maps.
function stringifyData(data = {}) {
  return Object.entries(data).reduce((acc, [key, value]) => {
    if (value === undefined || value === null) return acc;
    acc[key] = typeof value === 'string' ? value : JSON.stringify(value);
    return acc;
  }, {});
}

const UNREGISTERED_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

async function tokensFor({ ownerId, ownerType }) {
  if (!ownerId || !ownerType) return [];
  const rows = await prisma.deviceToken.findMany({ where: { ownerId, ownerType }, select: { token: true } });
  return rows.map((row) => row.token);
}

async function tokensForAudience(ownerType) {
  const rows = await prisma.deviceToken.findMany({ where: { ownerType }, select: { token: true } });
  return rows.map((row) => row.token);
}

async function pruneTokens(tokens) {
  if (!tokens.length) return;
  try {
    await prisma.deviceToken.deleteMany({ where: { token: { in: tokens } } });
    console.log(`[FCM] Pruned ${tokens.length} unregistered device token(s).`);
  } catch (err) {
    console.error('[FCM] Could not prune device tokens:', err.message);
  }
}

/**
 * Sends a multicast to the given tokens and prunes the dead ones.
 * @returns {Promise<{ success: boolean, successCount: number, failureCount: number }>}
 */
async function sendToTokens(tokens, { title, body, data }) {
  const messaging = firebase.getMessaging();
  if (!messaging) return { success: false, successCount: 0, failureCount: tokens.length };

  const unique = [...new Set(tokens.filter(Boolean))];
  if (!unique.length) return { success: true, successCount: 0, failureCount: 0 };

  let successCount = 0;
  let failureCount = 0;
  const dead = [];

  // sendEachForMulticast caps at 500 tokens per call.
  for (let i = 0; i < unique.length; i += 500) {
    const batch = unique.slice(i, i + 500);
    try {
      const response = await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: stringifyData(data),
      });
      successCount += response.successCount;
      failureCount += response.failureCount;
      response.responses.forEach((result, index) => {
        if (!result.success && UNREGISTERED_CODES.has(result.error?.code)) dead.push(batch[index]);
      });
    } catch (err) {
      failureCount += batch.length;
      console.error('[FCM] Send failed:', err.message);
    }
  }

  await pruneTokens(dead);
  return { success: failureCount === 0, successCount, failureCount };
}

/**
 * Sends a single push notification.
 * @param {object} params
 * @param {string|string[]} [params.to] - FCM device token(s), if already known.
 * @param {string} [params.ownerId] - user/doctor/admin id to look up stored tokens for.
 * @param {'USER'|'DOCTOR'|'ADMIN'} [params.ownerType] - which table ownerId belongs to.
 * @param {string} params.title
 * @param {string} params.body
 * @param {object} [params.data] - arbitrary extra payload (e.g. { caseId })
 */
async function sendPushNotification({ to, ownerId, ownerType, title, body, data = {} }) {
  const explicit = Array.isArray(to) ? to : (to ? [to] : []);
  const stored = isConfigured ? await tokensFor({ ownerId, ownerType }) : [];
  const tokens = [...explicit, ...stored];

  if (!isConfigured || !tokens.length) {
    const suffix = isConfigured ? ' (no device tokens on file)' : ' (no Firebase credentials configured, logging only)';
    console.log(`[FCM STUB] Push notification${suffix}:`, {
      to: tokens.length ? tokens.length + ' token(s)' : '(no device token on file)',
      title,
      body,
      data,
    });
    return { success: true, stub: true, messageId: `stub-${Date.now()}` };
  }

  const result = await sendToTokens(tokens, { title, body, data });
  return { ...result, stub: false, messageId: `fcm-${Date.now()}` };
}

/**
 * Sends a push notification to a whole audience ("all-users", "all-doctors",
 * "all-admins"), or to a genuine FCM topic for any other topic name.
 */
async function sendPushToTopic({ topic, title, body, data = {} }) {
  if (!isConfigured) {
    console.log('[FCM STUB] Push notification to topic:', { topic, title, body, data });
    return { success: true, stub: true, messageId: `stub-topic-${Date.now()}` };
  }

  const audience = TOPIC_AUDIENCES[topic];
  if (audience) {
    const tokens = await tokensForAudience(audience);
    if (!tokens.length) {
      console.log('[FCM STUB] Push notification to topic (no device tokens on file):', { topic, title, body, data });
      return { success: true, stub: true, messageId: `stub-topic-${Date.now()}` };
    }
    const result = await sendToTokens(tokens, { title, body, data });
    return { ...result, stub: false, messageId: `fcm-topic-${Date.now()}` };
  }

  const messaging = firebase.getMessaging();
  try {
    const messageId = await messaging.send({ topic, notification: { title, body }, data: stringifyData(data) });
    return { success: true, stub: false, messageId };
  } catch (err) {
    console.error('[FCM] Topic send failed:', err.message);
    return { success: false, stub: false, messageId: null };
  }
}

module.exports = { sendPushNotification, sendPushToTopic, isConfigured };
