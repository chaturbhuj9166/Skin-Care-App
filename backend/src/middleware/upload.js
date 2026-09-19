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

const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.pdf']);

function fileFilter(req, file, cb) {
  const ext = path.extname(file.originalname).toLowerCase();
  if (!ALLOWED_EXTENSIONS.has(ext)) {
    return cb(new Error('Unsupported file type'));
  }
  cb(null, true);
}

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

module.exports = { upload, UPLOAD_DIR };
