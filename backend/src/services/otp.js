// Server-generated one-time codes for phone login.
//
// sendOtp() creates a fresh 6-digit code for a phone number and stores only
// its hash; verifyOtp() checks a submitted code against the latest unused,
// unexpired code for that number. There is no SMS provider yet - the caller
// decides (env.OTP_SHOW_IN_RESPONSE) whether to hand the plain code back to
// the app so it can be shown on screen.
const crypto = require('crypto');
const prisma = require('../config/db');
const ApiError = require('../utils/ApiError');

const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 30 * 1000;
const MAX_ATTEMPTS = 5;

function generateCode() {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

function hashCode(phone, code) {
  return crypto.createHash('sha256').update(`${phone}:${code}`).digest('hex');
}

function codesMatch(phone, code, codeHash) {
  const a = Buffer.from(hashCode(phone, code), 'hex');
  const b = Buffer.from(codeHash, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

async function sendOtp(phone) {
  const latest = await prisma.otpCode.findFirst({
    where: { phone },
    orderBy: { createdAt: 'desc' },
  });
  if (latest && Date.now() - latest.createdAt.getTime() < RESEND_COOLDOWN_MS) {
    const wait = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - latest.createdAt.getTime())) / 1000);
    throw ApiError.badRequest(`Please wait ${wait}s before requesting a new code`);
  }

  // Only the newest code is ever valid for a number.
  await prisma.otpCode.updateMany({
    where: { phone, consumedAt: null },
    data: { consumedAt: new Date() },
  });

  const code = generateCode();
  await prisma.otpCode.create({
    data: { phone, codeHash: hashCode(phone, code), expiresAt: new Date(Date.now() + OTP_TTL_MS) },
  });

  return { code, expiresInSeconds: OTP_TTL_MS / 1000 };
}

async function verifyOtp(phone, code) {
  const otp = await prisma.otpCode.findFirst({
    where: { phone, consumedAt: null },
    orderBy: { createdAt: 'desc' },
  });
  if (!otp) throw ApiError.badRequest('No active code for this number. Please request a new one.');
  if (otp.expiresAt < new Date()) throw ApiError.badRequest('This code has expired. Please request a new one.');
  if (otp.attempts >= MAX_ATTEMPTS) throw ApiError.badRequest('Too many wrong attempts. Please request a new code.');

  if (!codesMatch(phone, code, otp.codeHash)) {
    await prisma.otpCode.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    const left = MAX_ATTEMPTS - otp.attempts - 1;
    throw ApiError.badRequest(left > 0 ? `Incorrect code. ${left} attempt(s) left.` : 'Too many wrong attempts. Please request a new code.');
  }

  await prisma.otpCode.update({ where: { id: otp.id }, data: { consumedAt: new Date() } });
}

module.exports = { sendOtp, verifyOtp, generateCode, hashCode, codesMatch, MAX_ATTEMPTS };
