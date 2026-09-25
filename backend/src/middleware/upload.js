const multer = require('multer');
const path = require('node:path');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');

// Local disk fallback for when Cloudinary isn't configured (e.g. local dev
// without credentials). Kept on disk here so /uploads/:file can still serve
// it - see upload.routes.js for the Cloudinary path.
const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// Files are buffered in memory rather than written straight to disk so the
// same upload can go to Cloudinary (a stream upload) or, as a fallback, to
// local disk - see upload.routes.js.
const storage = multer.memoryStorage();

// Every accepted extension maps to the mimetypes we'll accept for it, so a
// ".mp4" carrying an "image/png" mimetype (or the reverse) is rejected - the
// extension alone isn't trusted. Videos cover what phone cameras produce:
// .mp4 (Android), .mov (iOS) and .webm.
const ALLOWED_TYPES = {
  '.jpg': ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.png': ['image/png'],
  '.webp': ['image/webp'],
  '.gif': ['image/gif'],
  '.pdf': ['application/pdf'],
  '.mp4': ['video/mp4'],
  '.mov': ['video/quicktime', 'video/mp4'],
  '.webm': ['video/webm'],
};

const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB - enough for a short phone clip

function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedMimetypes = ALLOWED_TYPES[ext];
  if (!allowedMimetypes) {
    return cb(new Error(`Unsupported file type "${ext || file.originalname}". Allowed: ${Object.keys(ALLOWED_TYPES).join(', ')}`));
  }
  if (!allowedMimetypes.includes((file.mimetype || '').toLowerCase())) {
    return cb(new Error(`File content type "${file.mimetype}" does not match the "${ext}" extension`));
  }
  cb(null, true);
}

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: MAX_FILE_SIZE },
});

module.exports = { upload, UPLOAD_DIR, MAX_FILE_SIZE, ALLOWED_TYPES };
