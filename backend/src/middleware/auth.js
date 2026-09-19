const prisma = require('../config/db');
const { verifyToken, ROLES } = require('../utils/jwt');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const sanitize = require('../utils/sanitize');

/**
 * Verifies the `Authorization: Bearer <token>` header and attaches the
 * decoded payload as `req.auth = { id, role }`. Does NOT hit the database -
 * use one of the `require*` guards below for that + to attach the full
 * req.user / req.doctor / req.admin record.
 */
function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(ApiError.unauthorized('Missing or malformed Authorization header'));
  }

  try {
    const payload = verifyToken(token);
    req.auth = { id: payload.id, role: payload.role };
    next();
  } catch (err) {
    next(ApiError.unauthorized('Invalid or expired token'));
  }
}

/**
 * Role guard factory. Ensures the authenticated token belongs to the
 * expected role, loads the corresponding record from the database, and
 * attaches it to the request (req.user / req.doctor / req.admin).
 */
function requireRole(role) {
  return asyncHandler(async (req, res, next) => {
    if (!req.auth || req.auth.role !== role) {
      throw ApiError.forbidden('You do not have access to this resource');
    }

    if (role === ROLES.USER) {
      const user = await prisma.user.findUnique({ where: { id: req.auth.id } });
      if (!user) throw ApiError.unauthorized('User account no longer exists');
      if (user.isBlocked) throw ApiError.forbidden('This account has been blocked');
      req.user = user;
      return next();
    }

    if (role === ROLES.DOCTOR) {
      const doctor = await prisma.doctor.findUnique({ where: { id: req.auth.id } });
      if (!doctor) throw ApiError.unauthorized('Doctor account no longer exists');
      req.doctor = sanitize(doctor);
      return next();
    }

    if (role === ROLES.ADMIN) {
      const admin = await prisma.admin.findUnique({ where: { id: req.auth.id } });
      if (!admin) throw ApiError.unauthorized('Admin account no longer exists');
      req.admin = sanitize(admin);
      return next();
    }

    throw ApiError.forbidden('Unknown role');
  });
}

module.exports = {
  authenticate,
  requireRole,
  requireUser: requireRole(ROLES.USER),
  requireDoctor: requireRole(ROLES.DOCTOR),
  requireAdmin: requireRole(ROLES.ADMIN),
};
