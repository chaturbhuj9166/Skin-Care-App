// Firebase Cloud Messaging service — STUBBED.
//
// No real Firebase project is connected yet. Instead of calling
// `firebase-admin`, this module logs what WOULD have been sent so the rest
// of the codebase (controllers, notification flows) can be written exactly
// as if push notifications were live.
//
// To go live later:
//   1. `npm install firebase-admin`
//   2. Fill in FIREBASE_PROJECT_ID / FIREBASE_PRIVATE_KEY / FIREBASE_CLIENT_EMAIL in .env
//   3. Replace the body of sendPushNotification() (and sendPushToTopic) with:
//        const admin = require('firebase-admin');
//        if (!admin.apps.length) {
//          admin.initializeApp({ credential: admin.credential.cert({...}) });
//        }
//        return admin.messaging().send({ token: to, notification: { title, body }, data });
//      Every call site stays unchanged.
const env = require('../config/env');

const isConfigured = Boolean(env.FIREBASE_PROJECT_ID && env.FIREBASE_PRIVATE_KEY && env.FIREBASE_CLIENT_EMAIL);

/**
 * Sends (or, currently, logs) a single push notification.
 * @param {object} params
 * @param {string} [params.to] - FCM device token, if known. Optional since
 *   this app does not yet persist device tokens anywhere.
 * @param {string} params.title
 * @param {string} params.body
 * @param {object} [params.data] - arbitrary extra payload (e.g. { caseId })
 */
async function sendPushNotification({ to, title, body, data = {} }) {
  const suffix = isConfigured ? '' : ' (no Firebase credentials configured, logging only)';
  console.log(`[FCM STUB] Push notification${suffix}:`, {
    to: to || '(no device token on file)',
    title,
    body,
    data,
  });
  return { success: true, stub: !isConfigured, messageId: `stub-${Date.now()}` };
}

/**
 * Sends (or, currently, logs) a push notification to every subscriber of a
 * topic (e.g. "all-users", "all-doctors").
 */
async function sendPushToTopic({ topic, title, body, data = {} }) {
  console.log('[FCM STUB] Push notification to topic:', { topic, title, body, data });
  return { success: true, stub: !isConfigured, messageId: `stub-topic-${Date.now()}` };
}

module.exports = { sendPushNotification, sendPushToTopic, isConfigured };
