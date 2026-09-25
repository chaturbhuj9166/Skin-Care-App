// Firebase Admin SDK bootstrap — the single place the whole backend gets its
// `firebase-admin` app from (FCM push in services/fcm.js, ID-token
// verification in controllers/auth.controller.js, object storage in
// services/firebaseStorage.js).
//
// Credentials can be supplied two ways:
//   1. FIREBASE_SERVICE_ACCOUNT_PATH — path to the downloaded service-account
//      JSON file (relative paths resolve from the backend/ folder). Wins when
//      both are set. Easiest locally; the file is gitignored.
//   2. FIREBASE_PROJECT_ID + FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY —
//      the three env vars, for hosts where you cannot ship a file (Railway).
//      The private key may contain literal "\n" escapes; they are unescaped
//      here so you can paste the key on a single line.
//
// Nothing is required to run the server: when neither option is configured
// `isConfigured` is false and every Firebase-dependent path degrades to the
// same stub behaviour it had before Firebase existed (console-log pushes,
// Cloudinary/local-disk uploads, dev OTP login).
const path = require('node:path');
const fs = require('node:fs');
const env = require('../config/env');

function loadServiceAccountFromFile() {
  const configured = env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!configured) return null;

  const filePath = path.isAbsolute(configured) ? configured : path.join(__dirname, '..', '..', configured);
  if (!fs.existsSync(filePath)) {
    console.warn(`[firebase] FIREBASE_SERVICE_ACCOUNT_PATH points at a missing file: ${filePath}`);
    return null;
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      console.warn('[firebase] Service-account file is missing project_id/client_email/private_key.');
      return null;
    }
    return {
      projectId: parsed.project_id,
      clientEmail: parsed.client_email,
      privateKey: parsed.private_key,
      source: `file ${path.basename(filePath)}`,
    };
  } catch (err) {
    console.warn(`[firebase] Could not read service-account file: ${err.message}`);
    return null;
  }
}

function loadServiceAccountFromEnv() {
  if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_CLIENT_EMAIL || !env.FIREBASE_PRIVATE_KEY) return null;
  return {
    projectId: env.FIREBASE_PROJECT_ID,
    clientEmail: env.FIREBASE_CLIENT_EMAIL,
    // Hosting dashboards store the key on one line, often wrapped in quotes,
    // with the line breaks written as the two characters \ and n.
    privateKey: env.FIREBASE_PRIVATE_KEY.trim().replace(/^"|"$/g, '').replace(/\\n/g, '\n'),
    source: 'env vars',
  };
}

// File path wins when both are configured.
const serviceAccount = loadServiceAccountFromFile() || loadServiceAccountFromEnv();

const isConfigured = Boolean(serviceAccount);
const projectId = serviceAccount ? serviceAccount.projectId : '';
const storageBucket = env.FIREBASE_STORAGE_BUCKET || (projectId ? `${projectId}.firebasestorage.app` : '');

// One boot-time line so the logs make it obvious which mode we are in. The
// SDK itself is only initialized on first use (getApp() below).
if (env.NODE_ENV !== 'test') {
  console.log(
    isConfigured
      ? `[firebase] Configured for project ${projectId} via ${serviceAccount.source}; storage bucket ${storageBucket}.`
      : '[firebase] Not configured - push, Storage uploads and Firebase login fall back to their stubs.',
  );
}

let app = null;
let initError = null;

/**
 * Returns the initialized firebase-admin App, or null when Firebase is not
 * configured (or failed to initialize). Initialization is lazy so requiring
 * this module never slows down / breaks boot.
 */
function getApp() {
  if (!isConfigured || initError) return null;
  if (app) return app;

  try {
    // firebase-admin v14 only ships the modular entry points, so require the
    // sub-modules rather than the old `admin.credential` namespace.
    const { initializeApp, getApps, getApp: getDefaultApp, cert } = require('firebase-admin/app');
    // Reuse the default app if something else already created it.
    app = getApps().length
      ? getDefaultApp()
      : initializeApp({
          credential: cert({
            projectId: serviceAccount.projectId,
            clientEmail: serviceAccount.clientEmail,
            privateKey: serviceAccount.privateKey,
          }),
          ...(storageBucket && { storageBucket }),
        });
    console.log(`[firebase] Admin SDK initialized for project ${serviceAccount.projectId} (${serviceAccount.source}).`);
    return app;
  } catch (err) {
    initError = err;
    console.error(`[firebase] Admin SDK initialization failed: ${err.message}`);
    return null;
  }
}

/** firebase-admin Auth, or null when Firebase is not configured. */
function getAuth() {
  const initialized = getApp();
  return initialized ? require('firebase-admin/auth').getAuth(initialized) : null;
}

/** firebase-admin Messaging, or null when Firebase is not configured. */
function getMessaging() {
  const initialized = getApp();
  return initialized ? require('firebase-admin/messaging').getMessaging(initialized) : null;
}

/** The default Cloud Storage bucket, or null when Firebase is not configured. */
function getBucket() {
  const initialized = getApp();
  if (!initialized || !storageBucket) return null;
  return require('firebase-admin/storage').getStorage(initialized).bucket(storageBucket);
}

module.exports = { isConfigured, projectId, storageBucket, getApp, getAuth, getMessaging, getBucket };
