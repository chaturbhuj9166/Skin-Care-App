// Cloudinary object storage. Falls back to local disk (see upload.routes.js)
// whenever credentials aren't set - same pattern as fcm.js/agora.js.
const { v2: cloudinary } = require('cloudinary');
const env = require('../config/env');

const isConfigured = Boolean(env.CLOUDINARY_CLOUD_NAME && env.CLOUDINARY_API_KEY && env.CLOUDINARY_API_SECRET);

if (isConfigured) {
  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

function uploadBuffer(buffer, { folder = 'skincare-app' } = {}) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: 'auto' },
      (err, result) => (err ? reject(err) : resolve(result)),
    );
    stream.end(buffer);
  });
}

module.exports = { isConfigured, uploadBuffer };
