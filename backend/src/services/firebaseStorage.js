// Firebase Cloud Storage uploads - the preferred driver for case photos,
// prescription attachments and avatars. Falls back to Cloudinary and then to
// local disk (see upload.routes.js) whenever Firebase isn't configured -
// same pattern as fcm.js/agora.js/cloudinary.js.
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const firebase = require('./firebase');

const isConfigured = firebase.isConfigured && Boolean(firebase.storageBucket);

/**
 * Uploads a buffer to the project's Storage bucket and returns a public URL.
 *
 * The object is made public (`file.makePublic()`), so the returned
 * storage.googleapis.com URL works for anyone with the link - no signing, no
 * expiry, which is what the app needs for photos rendered inside chat/case
 * screens.
 *
 * @param {Buffer} buffer
 * @param {object} options
 * @param {string} [options.folder] - prefix inside the bucket
 * @param {string} [options.originalname] - used only for the file extension
 * @param {string} [options.contentType]
 * @returns {Promise<{ url: string, path: string }>}
 */
async function uploadBuffer(buffer, { folder = 'skincare', originalname = '', contentType } = {}) {
  const bucket = firebase.getBucket();
  if (!bucket) throw new Error('Firebase Storage is not configured');

  const ext = path.extname(originalname).toLowerCase();
  const objectPath = `${folder}/${randomUUID()}${ext}`;
  const file = bucket.file(objectPath);

  await file.save(buffer, {
    resumable: false,
    contentType: contentType || 'application/octet-stream',
    metadata: { cacheControl: 'public, max-age=31536000' },
  });
  await file.makePublic();

  return {
    url: `https://storage.googleapis.com/${bucket.name}/${encodeURI(objectPath)}`,
    path: objectPath,
  };
}

module.exports = { isConfigured, uploadBuffer };
