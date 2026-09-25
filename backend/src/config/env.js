// Centralized environment variable access. Loads .env once and exposes a
// single typed-ish object so the rest of the codebase never touches
// `process.env` directly.
require('dotenv').config();

const env = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: parseInt(process.env.PORT, 10) || 5000,

  DATABASE_URL: process.env.DATABASE_URL,

  JWT_SECRET: process.env.JWT_SECRET || 'dev-only-insecure-secret',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'dev-only-insecure-refresh-secret',
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || '7d',

  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',

  // No SMS provider is wired up yet, so by default the generated OTP is sent
  // back in the send-otp response and the app shows it on screen. Set to
  // "false" once real SMS delivery (Firebase/MSG91/...) is integrated.
  OTP_SHOW_IN_RESPONSE: process.env.OTP_SHOW_IN_RESPONSE !== 'false',

  // Path to a downloaded service-account JSON file. Takes precedence over the
  // three vars below - see services/firebase.js.
  FIREBASE_SERVICE_ACCOUNT_PATH: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '',
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || '',
  FIREBASE_PRIVATE_KEY: process.env.FIREBASE_PRIVATE_KEY || '',
  FIREBASE_CLIENT_EMAIL: process.env.FIREBASE_CLIENT_EMAIL || '',
  // Cloud Storage bucket for photo/file uploads. Defaults to
  // "<project-id>.firebasestorage.app" when left empty.
  FIREBASE_STORAGE_BUCKET: process.env.FIREBASE_STORAGE_BUCKET || '',

  AGORA_APP_ID: process.env.AGORA_APP_ID || '',
  AGORA_APP_CERTIFICATE: process.env.AGORA_APP_CERTIFICATE || '',

  CLOUDINARY_CLOUD_NAME: process.env.CLOUDINARY_CLOUD_NAME || '',
  CLOUDINARY_API_KEY: process.env.CLOUDINARY_API_KEY || '',
  CLOUDINARY_API_SECRET: process.env.CLOUDINARY_API_SECRET || '',
};

if (env.NODE_ENV !== 'test' && !env.DATABASE_URL) {
  // Not fatal at require-time (so tooling like `prisma generate` still works
  // without a .env file), but the app will fail fast once it tries to talk
  // to the database.
  console.warn('[env] DATABASE_URL is not set. Copy .env.example to .env and configure it.');
}

module.exports = env;
