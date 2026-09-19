const express = require('express');
const path = require('node:path');
const fs = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const { authenticate } = require('../middleware/auth');
const { upload, UPLOAD_DIR } = require('../middleware/upload');
const cloudinaryService = require('../services/cloudinary');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');

const router = express.Router();

router.use(authenticate);

// POST /api/upload - multipart/form-data, field name "file".
// Any authenticated role (user/doctor/admin) may upload - used for case
// photos, chat attachments and profile avatars alike.
router.post(
  '/',
  (req, res, next) => {
    upload.single('file')(req, res, (err) => {
      if (err) return next(ApiError.badRequest(err.message));
      next();
    });
  },
  asyncHandler(async (req, res) => {
    if (!req.file) throw ApiError.badRequest('No file provided');

    if (cloudinaryService.isConfigured) {
      const result = await cloudinaryService.uploadBuffer(req.file.buffer, { folder: 'skincare-app' });
      return res.status(201).json({ url: result.secure_url });
    }

    // Local disk fallback (no Cloudinary credentials configured).
    const ext = path.extname(req.file.originalname).toLowerCase();
    const filename = `${randomUUID()}${ext}`;
    await fs.writeFile(path.join(UPLOAD_DIR, filename), req.file.buffer);
    const url = `${req.protocol}://${req.get('host')}/uploads/${filename}`;
    res.status(201).json({ url });
  }),
);

module.exports = router;
