const express = require('express');
const { z } = require('zod');
const validate = require('../middleware/validate');
const authController = require('../controllers/auth.controller');

const router = express.Router();

const adminLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const userRegisterSchema = z.object({
  name: z.string().min(1),
  phone: z.string().min(6),
  email: z.string().email().optional(),
});

const userLoginSchema = z.object({
  phone: z.string().min(6),
});

const verifyOtpSchema = z.object({
  phone: z.string().min(6),
  otp: z.string().regex(/^\d{6}$/, 'OTP must be a 6-digit code'),
});

router.post('/admin/login', validate({ body: adminLoginSchema }), authController.adminLogin);
router.post('/user/register', validate({ body: userRegisterSchema }), authController.userRegister);
router.post('/user/login', validate({ body: userLoginSchema }), authController.userLogin);
router.post('/verify-otp', validate({ body: verifyOtpSchema }), authController.verifyOtp);

module.exports = router;
