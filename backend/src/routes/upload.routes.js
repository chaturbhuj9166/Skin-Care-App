const express = require('express');
const path = require('node:path');
const fs = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const { authenticate } = require('../middleware/auth');
const { upload, UPLOAD_DIR, MAX_FILE_SIZE } = require('../middleware/upload');
const firebaseStorage = require('../services/firebaseStorage');
const cloudinaryService = require('../services/cloudinary');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');

const router = express.Router();

router.use(authenticate);

// POST /api/upload - multipart/form-data, field name "file".
// Any authenticated role (user/doctor/admin) may upload - used for case
// photos and videos, chat attachments and profile avatars alike.
router.post(
  '/',
  (req, res, next) => {
    upload.single('file')(req, res, (err) => {
      if (!err) return next();
      // Multer's own errors ("File too large", "Unexpected field") are terse,
      // so spell them out - the app shows this message to the patient.
      if (err.code === 'LIMIT_FILE_SIZE') {
        return next(ApiError.badRequest(`File is too large. The maximum upload size is ${Math.round(MAX_FILE_SIZE / (1024 * 1024))}MB`));
      }
      if (err.code === 'LIMIT_UNEXPECTED_FILE') {
        return next(ApiError.badRequest('Unexpected file field. Send the file in a field named "file"'));
      }
      next(ApiError.badRequest(err.message));
    });
  },
  asyncHandler(async (req, res) => {
    if (!req.file) throw ApiError.badRequest('No file provided');

    // Driver order: Firebase Storage -> Cloudinary -> local disk.
    if (firebaseStorage.isConfigured) {
      const result = await firebaseStorage.uploadBuffer(req.file.buffer, {
        folder: 'skincare',
        originalname: req.file.originalname,
        contentType: req.file.mimetype,
      });
      return res.status(201).json({ url: result.url });
    }

    if (cloudinaryService.isConfigured) {
      const result = await cloudinaryService.uploadBuffer(req.file.buffer, { folder: 'skincare-app' });
      return res.status(201).json({ url: result.secure_url });
    }

    // Local disk fallback (neither Firebase nor Cloudinary configured).
    const ext = path.extname(req.file.originalname).toLowerCase();
    const filename = `${randomUUID()}${ext}`;
    await fs.writeFile(path.join(UPLOAD_DIR, filename), req.file.buffer);
    const url = `${req.protocol}://${req.get('host')}/uploads/${filename}`;
    res.status(201).json({ url });
  }),
);

module.exports = router;
