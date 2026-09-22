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

const phoneSchema = z
  .string()
  .trim()
  .regex(/^\+?\d{8,15}$/, 'Enter a valid phone number')
  // Indian mobile numbers are exactly 10 digits starting with 6-9.
  .refine((p) => !p.startsWith('+91') || /^\+91[6-9]\d{9}$/.test(p), 'Enter a valid 10-digit Indian mobile number');

const sendOtpSchema = z.object({
  phone: phoneSchema,
});

const verifyOtpSchema = z.object({
  phone: phoneSchema,
  otp: z.string().regex(/^\d{6}$/, 'OTP must be a 6-digit code'),
});

const doctorLoginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(1),
});

router.post('/admin/login', validate({ body: adminLoginSchema }), authController.adminLogin);
router.post('/user/register', validate({ body: userRegisterSchema }), authController.userRegister);
router.post('/send-otp', validate({ body: sendOtpSchema }), authController.sendOtp);
router.post('/verify-otp', validate({ body: verifyOtpSchema }), authController.verifyOtp);
// Same OTP check as /verify-otp - the spec lists both paths for user login.
router.post('/user/login', validate({ body: verifyOtpSchema }), authController.verifyOtp);
router.post('/doctor/login', validate({ body: doctorLoginSchema }), authController.doctorLogin);

module.exports = router;
