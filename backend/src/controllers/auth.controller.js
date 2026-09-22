const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const env = require('../config/env');
const otpService = require('../services/otp');
const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/ApiError');
const sanitize = require('../utils/sanitize');
const { signToken, ROLES } = require('../utils/jwt');

const SALT_ROUNDS = 10;

// POST /api/auth/admin/login
const adminLogin = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  const admin = await prisma.admin.findUnique({ where: { email } });
  if (!admin) throw ApiError.unauthorized('Invalid email or password');

  const valid = await bcrypt.compare(password, admin.password);
  if (!valid) throw ApiError.unauthorized('Invalid email or password');

  const token = signToken({ id: admin.id, role: ROLES.ADMIN });
  res.json({ token, admin: sanitize(admin) });
});

// POST /api/auth/user/register
const userRegister = asyncHandler(async (req, res) => {
  const { name, phone, email } = req.body;

  const existing = await prisma.user.findUnique({ where: { phone } });
  if (existing) throw ApiError.conflict('This phone number is already registered');

  const user = await prisma.user.create({ data: { name, phone, email } });
  const token = signToken({ id: user.id, role: ROLES.USER });
  res.status(201).json({ token, user });
});

// POST /api/auth/send-otp
// Generates a fresh 6-digit code for this phone number. No SMS provider is
// wired up yet, so while env.OTP_SHOW_IN_RESPONSE is on (the default) the
// code is returned as `devOtp` and the app shows it on screen.
const sendOtp = asyncHandler(async (req, res) => {
  const { phone } = req.body;

  const existing = await prisma.user.findUnique({ where: { phone } });
  if (existing?.isBlocked) throw ApiError.forbidden('This account has been blocked');

  const { code, expiresInSeconds } = await otpService.sendOtp(phone);
  res.json({
    message: 'OTP sent',
    expiresInSeconds,
    ...(env.OTP_SHOW_IN_RESPONSE && { devOtp: code }),
  });
});

// POST /api/auth/verify-otp  (also served as POST /api/auth/user/login)
// Patient login: checks the code issued by send-otp, then finds the User
// for this number (or creates a lightweight account on first login) and
// issues their JWT. Doctors do not log in here - they use email + password
// (POST /api/auth/doctor/login).
const verifyOtp = asyncHandler(async (req, res) => {
  const { phone, otp } = req.body;
  await otpService.verifyOtp(phone, otp);

  let user = await prisma.user.findUnique({ where: { phone } });
  if (!user) {
    user = await prisma.user.create({ data: { name: 'New User', phone } });
  }
  if (user.isBlocked) throw ApiError.forbidden('This account has been blocked');

  const token = signToken({ id: user.id, role: ROLES.USER });
  res.json({ token, role: 'USER', user });
});

// POST /api/auth/doctor/login
// Doctor accounts are only ever created by an Admin, who sets the password.
const doctorLogin = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  const doctor = await prisma.doctor.findUnique({ where: { email: email.toLowerCase() } });
  if (!doctor || !doctor.password) throw ApiError.unauthorized('Invalid email or password');

  const valid = await bcrypt.compare(password, doctor.password);
  if (!valid) throw ApiError.unauthorized('Invalid email or password');

  const token = signToken({ id: doctor.id, role: ROLES.DOCTOR });
  res.json({ token, role: 'DOCTOR', doctor: sanitize(doctor) });
});

module.exports = { adminLogin, userRegister, sendOtp, verifyOtp, doctorLogin, SALT_ROUNDS };
