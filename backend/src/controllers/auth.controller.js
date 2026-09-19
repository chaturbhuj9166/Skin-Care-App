const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
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

// POST /api/auth/user/login
// NOTE (mock provider): in production this would only run AFTER the client
// verifies a Firebase Phone-Auth OTP. Since no Firebase project is wired up
// here, this endpoint trusts the phone number as-is: it looks the user up
// (or creates a lightweight account on first login) and issues a JWT.
// See POST /api/auth/verify-otp for the OTP-flow-shaped equivalent.
const userLogin = asyncHandler(async (req, res) => {
  const { phone } = req.body;

  let user = await prisma.user.findUnique({ where: { phone } });
  if (!user) {
    user = await prisma.user.create({ data: { name: 'New User', phone } });
  }
  if (user.isBlocked) throw ApiError.forbidden('This account has been blocked');

  const token = signToken({ id: user.id, role: ROLES.USER });
  res.json({ token, user });
});

// POST /api/auth/verify-otp
// NOTE (mock provider): there is no real SMS/OTP provider wired up yet.
// ANY syntactically valid 6-digit code is accepted as correct - swap the
// body of this handler for a real verification call once a provider
// (Firebase/MSG91/etc.) is integrated.
//
// This single endpoint serves BOTH the User app and Doctor app logins from
// one phone-number form: a Doctor account only ever exists if an Admin
// created it (see admin.controller.js's createDoctor), so a phone number
// matching a Doctor record here proves this login belongs to that doctor -
// nobody can self-register as a doctor. Any other phone number is treated
// as a User, auto-creating a lightweight account on first login same as
// before.
const verifyOtp = asyncHandler(async (req, res) => {
  const { phone, otp } = req.body;

  if (!/^\d{6}$/.test(otp)) {
    throw ApiError.badRequest('OTP must be a 6-digit code');
  }

  const doctor = await prisma.doctor.findUnique({ where: { phone } });
  if (doctor) {
    const token = signToken({ id: doctor.id, role: ROLES.DOCTOR });
    return res.json({ token, role: 'DOCTOR', doctor: sanitize(doctor) });
  }

  let user = await prisma.user.findUnique({ where: { phone } });
  if (!user) {
    user = await prisma.user.create({ data: { name: 'New User', phone } });
  }
  if (user.isBlocked) throw ApiError.forbidden('This account has been blocked');

  const token = signToken({ id: user.id, role: ROLES.USER });
  res.json({ token, role: 'USER', user });
});

module.exports = { adminLogin, userRegister, userLogin, verifyOtp };
